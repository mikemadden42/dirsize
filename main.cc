#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

namespace fs = std::filesystem;

// Function to get current time as a string
std::string current_time() {
    std::time_t now = std::time(nullptr);
    char buf[100];
    std::strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", std::localtime(&now));
    return {buf};
}

// Function to calculate the size of a directory and its contents
uintmax_t calculate_directory_size(const fs::path& dir_path,
                                   std::ofstream& log_file) {
    uintmax_t size = 0;
    try {
        for (const auto& entry : fs::recursive_directory_iterator(dir_path)) {
            if (fs::is_regular_file(entry.status())) {
                size += fs::file_size(entry);
            }
        }
    } catch (const fs::filesystem_error& e) {
        log_file << current_time() << " - Filesystem error: " << e.what()
                 << " in directory: " << dir_path << std::endl;
    } catch (const std::exception& e) {
        log_file << current_time() << " - General exception: " << e.what()
                 << " in directory: " << dir_path << std::endl;
    }
    return size;
}

// Function to convert size to human-readable format
std::string human_readable_size(uintmax_t size) {
    constexpr uintmax_t KB = 1024;
    constexpr uintmax_t MB = KB * 1024;
    constexpr uintmax_t GB = MB * 1024;

    std::ostringstream oss;
    oss << std::fixed << std::setprecision(2);

    if (size >= GB) {
        oss << static_cast<double>(size) / GB << " GB";
    } else if (size >= MB) {
        oss << static_cast<double>(size) / MB << " MB";
    } else if (size >= KB) {
        oss << static_cast<double>(size) / KB << " KB";
    } else {
        oss << size << " bytes";
    }
    return oss.str();
}

int main() {
    // Open the log file for writing
    std::ofstream log_file("error_log.txt", std::ios::app);

    // Check if the log file was opened successfully
    if (!log_file.is_open()) {
        std::cerr << "Unable to open log file." << std::endl;
        return 1;
    }

    // Get the current directory
    fs::path current_path = fs::current_path();

    try {
        // Iterate through the entries in the current directory
        for (const auto& entry : fs::directory_iterator(current_path)) {
            // Check if the entry is a directory and not hidden
            if (entry.is_directory() &&
                entry.path().filename().string()[0] != '.') {
                log_file << current_time()
                         << " - Processing directory: " << entry.path()
                         << std::endl;
                uintmax_t dir_size =
                    calculate_directory_size(entry.path(), log_file);
                std::cout << std::left << std::setw(30)
                          << entry.path().filename().string()
                          << " Size: " << std::setw(10)
                          << human_readable_size(dir_size) << std::endl;
            }
        }
    } catch (const fs::filesystem_error& e) {
        log_file << current_time() << " - Filesystem error: " << e.what()
                 << std::endl;
    } catch (const std::exception& e) {
        log_file << current_time() << " - General exception: " << e.what()
                 << std::endl;
    }

    // The log file will be closed automatically when the ofstream object is
    // destroyed
    return 0;
}
