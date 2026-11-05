#include "TelemetryBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/ps/IOPowerSources.h>
#include <IOKit/ps/IOPSKeys.h>
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <sys/sysctl.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <net/route.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

int ms_sysctl_string(const char *key, char *output, int capacity) {
    size_t size = capacity;
    if (sysctlbyname(key, output, &size, NULL, 0) != 0) { output[0] = 0; return 0; }
    output[capacity - 1] = 0;
    return (int)size;
}
uint64_t ms_sysctl_uint(const char *key) {
    uint64_t value = 0; size_t size = sizeof(value);
    if (sysctlbyname(key, &value, &size, NULL, 0) != 0) return 0;
    return value;
}
int ms_cpu_ticks(MSCPUTicks *output, int capacity) {
    natural_t count = 0; processor_info_array_t info = NULL; mach_msg_type_number_t length = 0;
    if (host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &length) != KERN_SUCCESS) return 0;
    int result = count < capacity ? (int)count : capacity;
    for (int i = 0; i < result; i++) {
        output[i] = (MSCPUTicks){
            (uint32_t)info[i * CPU_STATE_MAX + CPU_STATE_USER],
            (uint32_t)info[i * CPU_STATE_MAX + CPU_STATE_SYSTEM],
            (uint32_t)info[i * CPU_STATE_MAX + CPU_STATE_IDLE],
            (uint32_t)info[i * CPU_STATE_MAX + CPU_STATE_NICE]
        };
    }
    vm_deallocate(mach_task_self(), (vm_address_t)info, length * sizeof(integer_t));
    return result;
}
MSMemory ms_memory(void) {
    MSMemory m = {0};
    vm_statistics64_data_t stats; mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    vm_size_t page = 0; host_page_size(mach_host_self(), &page);
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&stats, &count) != KERN_SUCCESS) return m;
    m.total = ms_sysctl_uint("hw.memsize");
    m.free = (uint64_t)stats.free_count * page;
    m.active = (uint64_t)stats.active_count * page;
    m.inactive = (uint64_t)stats.inactive_count * page;
    m.wired = (uint64_t)stats.wire_count * page;
    m.compressed = (uint64_t)stats.compressor_page_count * page;
    m.purgeable = (uint64_t)stats.purgeable_count * page;
    m.external = (uint64_t)stats.external_page_count * page;
    m.speculative = (uint64_t)stats.speculative_count * page;
    struct xsw_usage swap; size_t size = sizeof(swap);
    if (sysctlbyname("vm.swapusage", &swap, &size, NULL, 0) == 0) { m.swapUsed = swap.xsu_used; m.swapTotal = swap.xsu_total; }
    int pressure = -1; size_t pressureSize = sizeof(pressure);
    if (sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &pressureSize, NULL, 0) != 0) pressure = -1;
    m.pressure = pressure;
    m.valid = m.total > 0;
    return m;
}
static double number(CFDictionaryRef dictionary, CFStringRef key, double fallback) {
    CFTypeRef v = CFDictionaryGetValue(dictionary, key); double result;
    if (v && CFGetTypeID(v) == CFNumberGetTypeID() && CFNumberGetValue(v, kCFNumberDoubleType, &result)) return result;
    return fallback;
}
static bool boolean(CFDictionaryRef dictionary, CFStringRef key) {
    return CFDictionaryGetValue(dictionary, key) == kCFBooleanTrue;
}
MSBattery ms_battery(void) {
    MSBattery b = {0}; b.health = b.temperature = b.voltage = b.amperage = -1; b.minutes = -1;
    CFTypeRef blob = IOPSCopyPowerSourcesInfo();
    if (blob) {
        CFArrayRef list = IOPSCopyPowerSourcesList(blob);
        if (list) {
            for (CFIndex i = 0; i < CFArrayGetCount(list); i++) {
                CFDictionaryRef d = IOPSGetPowerSourceDescription(blob, CFArrayGetValueAtIndex(list, i));
                if (!d) continue;
                CFStringRef kind = CFDictionaryGetValue(d, CFSTR(kIOPSTypeKey));
                if (!kind || !CFEqual(kind, CFSTR(kIOPSInternalBatteryType))) continue;
                b.present = true; b.charging = boolean(d, CFSTR(kIOPSIsChargingKey));
                CFStringRef state = CFDictionaryGetValue(d, CFSTR(kIOPSPowerSourceStateKey));
                b.external = state && CFEqual(state, CFSTR(kIOPSACPowerValue));
                double max = number(d, CFSTR(kIOPSMaxCapacityKey), 100);
                b.percentage = max > 0 ? number(d, CFSTR(kIOPSCurrentCapacityKey), 0) / max * 100 : 0;
                b.minutes = (int)number(d, b.charging ? CFSTR(kIOPSTimeToFullChargeKey) : CFSTR(kIOPSTimeToEmptyKey), -1);
                break;
            }
            CFRelease(list);
        }
        CFRelease(blob);
    }
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"));
    if (service) {
        CFMutableDictionaryRef d = NULL;
        if (IORegistryEntryCreateCFProperties(service, &d, kCFAllocatorDefault, 0) == KERN_SUCCESS && d) {
            b.cycles = (int)number(d, CFSTR("CycleCount"), 0);
            CFTypeRef nested = CFDictionaryGetValue(d, CFSTR("BatteryData"));
            CFDictionaryRef bd = nested && CFGetTypeID(nested) == CFDictionaryGetTypeID() ? (CFDictionaryRef)nested : d;
            b.designCapacity = (int)number(d, CFSTR("DesignCapacity"), number(bd, CFSTR("DesignCapacity"), 0));
            b.maxCapacity = (int)number(d, CFSTR("AppleRawMaxCapacity"), number(bd, CFSTR("AppleRawMaxCapacity"), number(bd, CFSTR("FullChargeCapacity"), number(d, CFSTR("MaxCapacity"), 0))));
            b.currentCapacity = (int)number(d, CFSTR("AppleRawCurrentCapacity"), number(bd, CFSTR("AppleRawCurrentCapacity"), number(d, CFSTR("CurrentCapacity"), 0)));
            if (b.designCapacity > 0 && b.maxCapacity > 100) b.health = fmin(100, (double)b.maxCapacity / b.designCapacity * 100);
            double t = number(d, CFSTR("Temperature"), -1);
            if (t > 0) b.temperature = t / 100;
            b.voltage = number(d, CFSTR("Voltage"), -1000) / 1000;
            b.amperage = number(d, CFSTR("Amperage"), -1);
            if (b.amperage > INT32_MAX && b.amperage <= UINT32_MAX) b.amperage -= 4294967296.0;
            CFRelease(d);
        }
        IOObjectRelease(service);
    }
    return b;
}
MSNetwork ms_network(void) {
    // RTM_IFINFO2 carries 64-bit counters; getifaddrs exposes wrapping 32-bit counters.
    MSNetwork n = {0}; int mib[] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0}; size_t size = 0;
    if (sysctl(mib, 6, NULL, &size, NULL, 0) != 0 || size == 0) return n;
    char *buffer = malloc(size);
    if (!buffer) return n;
    if (sysctl(mib, 6, buffer, &size, NULL, 0) != 0) { free(buffer); return n; }
    char *end = buffer + size;
    for (char *p = buffer; p + sizeof(struct if_msghdr) <= end;) {
        struct if_msghdr *message = (struct if_msghdr *)p;
        if (message->ifm_msglen == 0 || p + message->ifm_msglen > end) break;
        if (message->ifm_type == RTM_IFINFO2 && message->ifm_msglen >= sizeof(struct if_msghdr2)) {
            struct if_msghdr2 *info = (struct if_msghdr2 *)p;
            char name[IF_NAMESIZE] = {0}; if_indextoname(info->ifm_index, name);
            if ((info->ifm_flags & IFF_UP) && (strncmp(name, "en", 2) == 0 || strncmp(name, "pdp_ip", 6) == 0)) {
                n.received += info->ifm_data.ifi_ibytes; n.sent += info->ifm_data.ifi_obytes; n.valid = true;
            }
        }
        p += message->ifm_msglen;
    }
    free(buffer); return n;
}
double ms_gpu_usage(void) {
    io_iterator_t iterator;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) != KERN_SUCCESS) return -1;
    io_service_t service; double result = -1;
    while ((service = IOIteratorNext(iterator))) {
        CFTypeRef value = IORegistryEntryCreateCFProperty(service, CFSTR("PerformanceStatistics"), kCFAllocatorDefault, 0);
        if (value && CFGetTypeID(value) == CFDictionaryGetTypeID()) {
            double usage = number((CFDictionaryRef)value, CFSTR("Device Utilization %"), -1);
            if (usage < 0) usage = number((CFDictionaryRef)value, CFSTR("GPU Activity(%)"), -1);
            if (usage >= 0 && usage <= 100) result = fmax(result, usage);
        }
        if (value) CFRelease(value);
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator); return result;
}

// Apple's SMC userspace ABI. This bridge intentionally issues read commands only.
typedef struct { uint8_t major, minor, build, reserved; uint16_t release; } SMCVersion;
typedef struct { uint16_t version, length; uint32_t cpu, gpu, memory; } SMCPLimit;
typedef struct { uint32_t size, type; uint8_t attributes; } SMCKeyInfo;
typedef struct {
    uint32_t key; SMCVersion version; SMCPLimit limit; SMCKeyInfo info;
    uint8_t result, status, command; uint32_t index; uint8_t bytes[32];
} SMCData;
static io_connect_t smc = 0;
static uint32_t tempKeys[1024]; static int tempCount = -1;
static uint32_t fourcc(const char *s) { return (uint32_t)(uint8_t)s[0] << 24 | (uint32_t)(uint8_t)s[1] << 16 | (uint32_t)(uint8_t)s[2] << 8 | (uint8_t)s[3]; }
static void keyString(uint32_t key, char *s) { for (int i = 0; i < 4; i++) s[i] = (char)(key >> (24 - i * 8)); s[4] = 0; }
static bool smcCall(SMCData *input, SMCData *output) {
    size_t size = sizeof(SMCData); memset(output, 0, size);
    return smc && IOConnectCallStructMethod(smc, 2, input, sizeof(SMCData), output, &size) == KERN_SUCCESS && output->result == 0;
}
static double readSMCValue(uint32_t key, bool temperatureOnly) {
    SMCData in = {0}, out = {0}; in.key = key; in.command = 9;
    if (!smcCall(&in, &out) || out.info.size == 0 || out.info.size > 32) return NAN;
    uint32_t size = out.info.size, type = out.info.type;
    if (temperatureOnly && type != fourcc("sp78") && type != fourcc("flt ")) return NAN;
    in.info.size = size; in.command = 5;
    if (!smcCall(&in, &out)) return NAN;
    char name[5]; keyString(type, name);
    return ms_decode_smc(name, out.bytes, size);
}
static double readSMC(uint32_t key) { return readSMCValue(key, false); }
double ms_decode_smc(const char *type, const uint8_t *b, uint32_t size) {
    if (strncmp(type, "sp78", 4) == 0 && size >= 2) return (int16_t)((uint16_t)b[0] << 8 | b[1]) / 256.0;
    if (strncmp(type, "fpe2", 4) == 0 && size >= 2) return ((uint16_t)b[0] << 8 | b[1]) / 4.0;
    if (strncmp(type, "flt ", 4) == 0 && size >= 4) { float f; memcpy(&f, b, 4); return f; }
    if (strncmp(type, "ui8 ", 4) == 0 && size >= 1) return b[0];
    if (strncmp(type, "ui16", 4) == 0 && size >= 2) return (uint16_t)b[0] << 8 | b[1];
    if (strncmp(type, "ui32", 4) == 0 && size >= 4) return (uint32_t)b[0] << 24 | (uint32_t)b[1] << 16 | (uint32_t)b[2] << 8 | b[3];
    return NAN;
}
bool ms_smc_open(void) {
    if (smc) return true;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return false;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &smc);
    IOObjectRelease(service); if (result != KERN_SUCCESS) { smc = 0; return false; }
    return true;
}
void ms_smc_close(void) { if (smc) IOServiceClose(smc); smc = 0; tempCount = -1; }
int ms_temperatures(MSTemperature *output, int capacity) {
    if (!ms_smc_open()) return 0;
    if (tempCount < 0) {
        tempCount = 0;
        double countValue = readSMC(fourcc("#KEY"));
        int count = isfinite(countValue) && countValue > 0 && countValue <= 30000 ? (int)countValue : 0;
        for (int i = 0; i < count && tempCount < 1024; i++) {
            SMCData in = {0}, out; in.command = 8; in.index = i;
            if (!smcCall(&in, &out) || (out.key >> 24) != 'T') continue;
            double v = readSMCValue(out.key, true);
            if (isfinite(v) && v > 0 && v < 130) tempKeys[tempCount++] = out.key;
        }
    }
    int result = 0;
    for (int i = 0; i < tempCount && result < capacity; i++) {
        double value = readSMCValue(tempKeys[i], true);
        if (!isfinite(value) || value <= 0 || value >= 130) continue;
        keyString(tempKeys[i], output[result].key); output[result++].value = value;
    }
    return result;
}
int ms_fans(MSFan *output, int capacity) {
    if (!ms_smc_open()) return 0;
    double countValue = readSMC(fourcc("FNum"));
    if (!isfinite(countValue) || countValue < 0 || countValue > 16) return 0;
    int count = (int)countValue, result = 0;
    for (int i = 0; i < count && result < capacity; i++) {
        char key[] = "F0Ac"; key[1] = '0' + i;
        double current = readSMC(fourcc(key));
        if (!isfinite(current) || current < 0) continue;
        key[2] = 'M'; key[3] = 'n'; double min = readSMC(fourcc(key));
        key[3] = 'x'; double max = readSMC(fourcc(key));
        output[result++] = (MSFan){i, current, min, max};
    }
    return result;
}

// Read-only counters supplied by IOBlockStorageDriver, mapped to BSD media names.
int ms_disk_io(MSDiskIO *output, int capacity) {
    io_iterator_t iterator = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) != KERN_SUCCESS) return 0;
    int count = 0; io_service_t service;
    while ((service = IOIteratorNext(iterator))) {
        CFTypeRef stats = IORegistryEntryCreateCFProperty(service, CFSTR("Statistics"), kCFAllocatorDefault, 0);
        CFTypeRef name = IORegistryEntrySearchCFProperty(service, kIOServicePlane, CFSTR("BSD Name"), kCFAllocatorDefault, kIORegistryIterateRecursively);
        if (count < capacity && stats && name && CFGetTypeID(stats) == CFDictionaryGetTypeID() && CFGetTypeID(name) == CFStringGetTypeID()) {
            double read = number((CFDictionaryRef)stats, CFSTR("Bytes (Read)"), -1);
            double written = number((CFDictionaryRef)stats, CFSTR("Bytes (Write)"), -1);
            if (read >= 0 && written >= 0 && CFStringGetCString((CFStringRef)name, output[count].name, sizeof(output[count].name), kCFStringEncodingUTF8)) {
                output[count].read = (uint64_t)read; output[count].written = (uint64_t)written; count++;
            }
        }
        if (stats) CFRelease(stats); if (name) CFRelease(name); IOObjectRelease(service);
    }
    IOObjectRelease(iterator); return count;
}
