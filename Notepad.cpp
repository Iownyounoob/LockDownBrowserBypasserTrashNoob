#include <windows.h>
#include <detours.h>
#include <wtsapi32.h>
#include <winternl.h>
#include <winsvc.h>
#include <stdio.h>
#include <string>
#include <sstream>

#define SystemRemoteProtocolInformation 0x23  // System information class for remote protocol detection
#define STATUS_SUCCESS ((NTSTATUS)0x00000000)  // Status success code for NTSTATUS
#define STATUS_OBJECT_NAME_NOT_FOUND ((NTSTATUS)0xC0000034L)

// Typedef for NtQuerySystemInformation
typedef NTSTATUS(WINAPI* pNtQuerySystemInformation)(
    SYSTEM_INFORMATION_CLASS SystemInformationClass,
    PVOID SystemInformation,
    ULONG SystemInformationLength,
    PULONG ReturnLength);

// Path to the log file
const char* logFilePath = "C:\\log.txt";

// Log message to a file
void LogToFile(const char* message)
{
    FILE* logFile;
    fopen_s(&logFile, logFilePath, "a"); // Open in append mode
    if (logFile != NULL)
    {
        fprintf(logFile, "%s\n", message); // Log message without unique tag
        fclose(logFile); // Close the file
    }
}

// Exported function
extern "C" __declspec(dllexport) void Init()
{
    LogToFile("DLL Initialized");
}

// Original function pointers
static int (WINAPI* Original_GetSystemMetrics)(int nIndex) = GetSystemMetrics;
static BOOL(WINAPI* Original_WTSQuerySessionInformation)(
    HANDLE hServer, DWORD SessionId, WTS_INFO_CLASS WTSInfoClass, LPTSTR* ppBuffer, DWORD* pBytesReturned) = WTSQuerySessionInformation;
static LONG(WINAPI* Original_RegQueryValueEx)(
    HKEY hKey, LPCSTR lpValueName, LPDWORD lpReserved, LPDWORD lpType, LPBYTE lpData, LPDWORD lpcbData) = RegQueryValueExA;
static pNtQuerySystemInformation Original_NtQuerySystemInformation = nullptr;  // To hold the original NtQuerySystemInformation

// Typedefs and original function pointers for service-related API functions
typedef BOOL(WINAPI* pQueryServiceStatus)(
    SC_HANDLE hService, 
    LPSERVICE_STATUS lpServiceStatus);
typedef SC_HANDLE(WINAPI* pOpenServiceA)(
    SC_HANDLE hSCManager, 
    LPCSTR lpServiceName, 
    DWORD dwDesiredAccess);
typedef BOOL(WINAPI* pEnumServicesStatusA)(
    SC_HANDLE hSCManager, 
    DWORD dwServiceType, 
    DWORD dwServiceState, 
    LPENUM_SERVICE_STATUSA lpServices, 
    DWORD cbBufSize, 
    LPDWORD pcbBytesNeeded, 
    LPDWORD lpServicesReturned, 
    LPDWORD lpResumeHandle);

static pQueryServiceStatus Original_QueryServiceStatus = nullptr;
static pOpenServiceA Original_OpenService = nullptr;
static pEnumServicesStatusA Original_EnumServicesStatus = nullptr;

// Typedef and pointer for RegOpenKeyExW
typedef LSTATUS(WINAPI* pRegOpenKeyExW)(
    HKEY hKey,
    LPCWSTR lpSubKey,
    DWORD ulOptions,
    REGSAM samDesired,
    PHKEY phkResult);
static pRegOpenKeyExW Original_RegOpenKeyExW = nullptr;

// Hooked RegOpenKeyExW function
LSTATUS WINAPI Hooked_RegOpenKeyExW(
    HKEY hKey,
    LPCWSTR lpSubKey,
    DWORD ulOptions,
    REGSAM samDesired,
    PHKEY phkResult)
{
    LogToFile("RegOpenKeyExW called");

    // Proper logging for wide strings (converted to multibyte for logging)
    char logMessage[1024];  // Increased size for large registry paths
    if (lpSubKey) {
        size_t convertedChars = wcstombs(logMessage, lpSubKey, sizeof(logMessage) - 1);
        if (convertedChars == (size_t)-1) {
            LogToFile("Failed to convert wide string to multibyte.");
        } else {
            logMessage[convertedChars] = '\0';  // Ensure null termination
            LogToFile(logMessage);
        }
    }

    // Call the original function so the registry operation proceeds
    LSTATUS result = Original_RegOpenKeyExW(hKey, lpSubKey, ulOptions, samDesired, phkResult);

    // If the original function failed, spoof success
    if (result != ERROR_SUCCESS) {
        LogToFile("RegOpenKeyExW failed, but spoofing STATUS_SUCCESS");
        result = ERROR_SUCCESS;  // Spoof success
    }

    // Optionally clear the registry handle (phkResult) if needed
    if (phkResult != nullptr) {
        *phkResult = NULL;  // Simulate no valid handle being returned
    }

    return result;
}

// Services to spoof
const char* servicesToSpoof[] = {
    "gcs",
    "vmictimesync",
    "TermService",
    "UmRdpService",
    "vmicguestinterface",
    "vmicheartbeat",
    "vmickvpexchange",
    "vmicshutdown",
    "vmicvmsession"
};

// Hooked QueryServiceStatus function to spoof service status
BOOL WINAPI Hooked_QueryServiceStatus(SC_HANDLE hService, LPSERVICE_STATUS lpServiceStatus)
{
    LogToFile("QueryServiceStatus called");

    if (lpServiceStatus != NULL) {
        lpServiceStatus->dwCurrentState = SERVICE_STOPPED;
        LogToFile("Spoofing service status as stopped.");
        return TRUE;
    }

    return Original_QueryServiceStatus(hService, lpServiceStatus);
}

// Hooked OpenService function to prevent detecting specific services
SC_HANDLE WINAPI Hooked_OpenService(SC_HANDLE hSCManager, LPCSTR lpServiceName, DWORD dwDesiredAccess)
{
    LogToFile("OpenService called");

    for (int i = 0; i < sizeof(servicesToSpoof) / sizeof(servicesToSpoof[0]); i++) {
        if (strcmp(lpServiceName, servicesToSpoof[i]) == 0) {
            LogToFile("Spoofing OpenService: pretending service does not exist.");
            SetLastError(ERROR_SERVICE_DOES_NOT_EXIST);
            return NULL;
        }
    }

    return Original_OpenService(hSCManager, lpServiceName, dwDesiredAccess);
}

// Hooked EnumServicesStatus function to filter out services
BOOL WINAPI Hooked_EnumServicesStatus(SC_HANDLE hSCManager, DWORD dwServiceType, DWORD dwServiceState, LPENUM_SERVICE_STATUSA lpServices, DWORD cbBufSize, LPDWORD pcbBytesNeeded, LPDWORD lpServicesReturned, LPDWORD lpResumeHandle)
{
    LogToFile("EnumServicesStatus called");

    BOOL result = Original_EnumServicesStatus(hSCManager, dwServiceType, dwServiceState, lpServices, cbBufSize, pcbBytesNeeded, lpServicesReturned, lpResumeHandle);

    if (result && lpServices != NULL && *lpServicesReturned > 0) {
        for (DWORD i = 0; i < *lpServicesReturned; i++) {
            for (int j = 0; j < sizeof(servicesToSpoof) / sizeof(servicesToSpoof[0]); j++) {
                if (strcmp(lpServices[i].lpServiceName, servicesToSpoof[j]) == 0) {
                    LogToFile("Spoofing EnumServicesStatus: filtering out VM service.");
                    lpServices[i].ServiceStatus.dwCurrentState = SERVICE_STOPPED;
                }
            }
        }
    }

    return result;
}

// Hooked GetSystemMetrics
int WINAPI Hooked_GetSystemMetrics(int nIndex)
{
    LogToFile("GetSystemMetrics called");
    char logMessage[100];
    sprintf_s(logMessage, "GetSystemMetrics parameter nIndex: %d", nIndex);
    LogToFile(logMessage);

    if (nIndex == SM_REMOTESESSION)
    {
        LogToFile("GetSystemMetrics: SM_REMOTESESSION detected, returning 0");
        return 0; // Always return 0 for remote session, indicating local session
    }

    int result = Original_GetSystemMetrics(nIndex); // Call original for other metrics
    sprintf_s(logMessage, "GetSystemMetrics returned: %d", result);
    LogToFile(logMessage);
    return result;
}

// Hooked WTSQuerySessionInformation
BOOL WINAPI Hooked_WTSQuerySessionInformation(
    HANDLE hServer, DWORD SessionId, WTS_INFO_CLASS WTSInfoClass, LPTSTR* ppBuffer, DWORD* pBytesReturned)
{
    LogToFile("WTSQuerySessionInformation called");

    char logMessage[100];
    sprintf_s(logMessage, "WTSInfoClass: %d", WTSInfoClass);
    LogToFile(logMessage);

    // Spoof for terminal and RDP related queries
    if (WTSInfoClass == WTSClientName || WTSInfoClass == WTSClientProtocolType || WTSInfoClass == WTSSessionId)
    {
        LogToFile("WTSQuerySessionInformation: Spoofing session info to return NULL");
        *ppBuffer = NULL;  // Return NULL to indicate no session information
        *pBytesReturned = 0; // No bytes returned
        return TRUE; // Indicate success
    }

    return Original_WTSQuerySessionInformation(hServer, SessionId, WTSInfoClass, ppBuffer, pBytesReturned);  // Call original for other queries
}

// Hooked RegQueryValueEx
LONG WINAPI Hooked_RegQueryValueEx(
    HKEY hKey, LPCSTR lpValueName, LPDWORD lpReserved, LPDWORD lpType, LPBYTE lpData, LPDWORD lpcbData)
{
    LogToFile("RegQueryValueEx called");

    // Log the registry value name
    char logMessage[256];
    sprintf_s(logMessage, "RegQueryValueEx lpValueName: %s", lpValueName);
    LogToFile(logMessage);

    // Check for base keys to return "Name Not Found"
    if (lpValueName) {
        // Return "Name Not Found" for HKLM\System\CurrentControlSet\Services\Tcpip
        if (strstr(lpValueName, "System\\CurrentControlSet\\Services\\Tcpip")) {
            LogToFile("RegQueryValueEx: Returning ERROR_FILE_NOT_FOUND for Tcpip services");
            return ERROR_FILE_NOT_FOUND;  // Simulate "Name Not Found"
        }
        // Return "Name Not Found" for HKLM\SOFTWARE\WOW6432Node\Microsoft\Cryptography
        if (strstr(lpValueName, "SOFTWARE\\WOW6432Node\\Microsoft\\Cryptography")) {
            LogToFile("RegQueryValueEx: Returning ERROR_FILE_NOT_FOUND for Cryptography");
            return ERROR_FILE_NOT_FOUND;  // Simulate "Name Not Found"
        }
        // Return "Name Not Found" for HKLM\SOFTWARE\Microsoft\Windows NT\\CurrentVersion
        if (strstr(lpValueName, "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion")) {
            LogToFile("RegQueryValueEx: Returning ERROR_FILE_NOT_FOUND for Windows NT CurrentVersion");
            return ERROR_FILE_NOT_FOUND;  // Simulate "Name Not Found"
        }
        // Return "Name Not Found" for HKLM\System\CurrentControlSet\Enum
        if (strstr(lpValueName, "System\\CurrentControlSet\\Enum")) {
            LogToFile("RegQueryValueEx: Returning ERROR_FILE_NOT_FOUND for Enum");
            return ERROR_FILE_NOT_FOUND;  // Simulate "Name Not Found"
        }
    }

    // Spoof for terminal, RDP, and virtual machine-related values
    if (lpValueName && (strstr(lpValueName, "Terminal") ||
        strstr(lpValueName, "RDP") ||
        strstr(lpValueName, "Remote Desktop Protection") ||
        strstr(lpValueName, "RemoteDesktopProtection") ||
        strstr(lpValueName, "VM") ||
        strstr(lpValueName, "Virtual") ||
        strstr(lpValueName, "Hyper-V") ||
        strstr(lpValueName, "Virtual Machine") ||
        strstr(lpValueName, "Guest") ||
        strstr(lpValueName, "VirtualMachine")))
    {
        LogToFile("RegQueryValueEx: Returning NULL for related registry value");
        *lpcbData = 0; // Set the size of the data to 0 to indicate NULL
        return ERROR_SUCCESS; // Indicate success
    }

    // Specific checks for known values
    if (lpValueName) {
        if (strcmp(lpValueName, "SystemBiosVersion") == 0) {
            LogToFile("Returning NULL for SystemBiosVersion");
            *lpcbData = 0; // Set the size of the data to 0 to indicate NULL
            return ERROR_SUCCESS; // Indicate success
        }

        if (strcmp(lpValueName, "VideoBiosVersion") == 0) {
            LogToFile("Returning NULL for VideoBiosVersion");
            *lpcbData = 0; // Set the size of the data to 0 to indicate NULL
            return ERROR_SUCCESS; // Indicate success
        }

        if (strcmp(lpValueName, "ProcessorNameString") == 0) {
            LogToFile("Returning NULL for ProcessorNameString");
            *lpcbData = 0; // Set the size of the data to 0 to indicate NULL
            return ERROR_SUCCESS; // Indicate success
        }
    }

    // Call the original function for other cases
    return Original_RegQueryValueEx(hKey, lpValueName, lpReserved, lpType, lpData, lpcbData);
}

// Hooked NtQuerySystemInformation
NTSTATUS WINAPI Hooked_NtQuerySystemInformation(
    SYSTEM_INFORMATION_CLASS SystemInformationClass,
    PVOID SystemInformation,
    ULONG SystemInformationLength,
    PULONG ReturnLength)
{
    LogToFile("NtQuerySystemInformation called");

    char logMessage[100];
    sprintf_s(logMessage, "NtQuerySystemInformation class: %d", SystemInformationClass);
    LogToFile(logMessage);

    // Universal spoofing for remote protocol information
    if (SystemInformationClass == SystemRemoteProtocolInformation ||
        SystemInformationClass == SystemProcessInformation) // Add more classes as needed
    {
        LogToFile("NtQuerySystemInformation: Spoofing information");
        if (SystemInformation && SystemInformationLength > 0)
        {
            ZeroMemory(SystemInformation, SystemInformationLength); // Zero the buffer
        }
        if (ReturnLength)
        {
            *ReturnLength = 0; // Indicate that no relevant data is being returned
        }
        return STATUS_SUCCESS; // Always return success
    }

    return Original_NtQuerySystemInformation(SystemInformationClass, SystemInformation, SystemInformationLength, ReturnLength);
}

// DLL entry point
BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
    if (DetourIsHelperProcess())
    {
        return TRUE;
    }

    if (fdwReason == DLL_PROCESS_ATTACH)
    {
        LogToFile("DLL_PROCESS_ATTACH: Installing hooks");
        DetourRestoreAfterWith();

        DetourTransactionBegin();
        DetourUpdateThread(GetCurrentThread());

        // Call the Init function
        Init();

        // Hook GetSystemMetrics
        DetourAttach(&(PVOID&)Original_GetSystemMetrics, Hooked_GetSystemMetrics);

        // Hook WTSQuerySessionInformation
        DetourAttach(&(PVOID&)Original_WTSQuerySessionInformation, Hooked_WTSQuerySessionInformation);

        // Hook RegQueryValueEx
        DetourAttach(&(PVOID&)Original_RegQueryValueEx, Hooked_RegQueryValueEx);

        // Hook NtQuerySystemInformation
        HMODULE hNtdll = GetModuleHandleA("ntdll.dll");
        if (hNtdll)
        {
            // Hook NtQuerySystemInformation
            Original_NtQuerySystemInformation = (pNtQuerySystemInformation)GetProcAddress(hNtdll, "NtQuerySystemInformation");
            if (Original_NtQuerySystemInformation)
            {
                DetourAttach(&(PVOID&)Original_NtQuerySystemInformation, Hooked_NtQuerySystemInformation);
            }
        }

        // Hook service-related functions
        HMODULE hAdvapi32 = GetModuleHandleA("advapi32.dll");
        if (hAdvapi32)
        {
            Original_QueryServiceStatus = (pQueryServiceStatus)GetProcAddress(hAdvapi32, "QueryServiceStatus");
            Original_OpenService = (pOpenServiceA)GetProcAddress(hAdvapi32, "OpenServiceA");
            Original_EnumServicesStatus = (pEnumServicesStatusA)GetProcAddress(hAdvapi32, "EnumServicesStatusA");

            if (Original_QueryServiceStatus)
            {
                DetourAttach(&(PVOID&)Original_QueryServiceStatus, Hooked_QueryServiceStatus);
            }
            if (Original_OpenService)
            {
                DetourAttach(&(PVOID&)Original_OpenService, Hooked_OpenService);
            }
            if (Original_EnumServicesStatus)
            {
                DetourAttach(&(PVOID&)Original_EnumServicesStatus, Hooked_EnumServicesStatus);
            }
        }

        // Commit the transaction
        LONG error = DetourTransactionCommit();
        if (error != NO_ERROR) {
            char logMessage[100];
            sprintf_s(logMessage, "DetourTransactionCommit failed with error code: %ld", error);
            LogToFile(logMessage);
        } else {
            LogToFile("DLL_PROCESS_ATTACH: Hooks installed successfully");
        }
    }

    return TRUE;
}
