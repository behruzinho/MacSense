#ifndef TELEMETRY_BRIDGE_H
#define TELEMETRY_BRIDGE_H
#include <stdint.h>
#include <stdbool.h>

typedef struct {
    uint64_t user, system, idle, nice;
} MSCPUTicks;
typedef struct {
    uint64_t total, free, active, inactive, wired, compressed, purgeable, external, speculative;
    uint64_t swapUsed, swapTotal;
    int pressure;
    bool valid;
} MSMemory;
typedef struct {
    bool present, charging, external;
    double percentage, health, temperature, voltage, amperage;
    int cycles, currentCapacity, maxCapacity, designCapacity, minutes;
} MSBattery;
typedef struct { uint64_t received, sent; bool valid; } MSNetwork;
typedef struct { char key[5]; double value; } MSTemperature;
typedef struct { int index; double current, minimum, maximum; } MSFan;

int ms_cpu_ticks(MSCPUTicks *output, int capacity);
MSMemory ms_memory(void);
MSBattery ms_battery(void);
MSNetwork ms_network(void);
double ms_gpu_usage(void);
bool ms_smc_open(void);
void ms_smc_close(void);
int ms_temperatures(MSTemperature *output, int capacity);
int ms_fans(MSFan *output, int capacity);
double ms_decode_smc(const char *type, const uint8_t *bytes, uint32_t size);
int ms_sysctl_string(const char *key, char *output, int capacity);
uint64_t ms_sysctl_uint(const char *key);
#endif
