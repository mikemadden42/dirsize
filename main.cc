#include <chrono>
#include <cstdint>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>

namespace fs = std::filesystem;

enum class LogLevel { INFO, ERROR };

std::ostream& operator<<(std::ostream& os, LogLevel level) {
    return os << (level == LogLevel::ERROR ? "ERROR" : "INFO");
}

// Function to get current time as a string
std::string current_time() {
    auto now = std::chrono::system_clock::now();
    std::time_t now_c = std::chrono::system_clock::to_time_t(now);

    std::ostringstream oss;
    oss << std::put_time(std::localtime(&now_c), "%Y-%m-%d %H:%M:%S");
    return oss.str();
}

// Function to log messages with different levels
void log_message(std::ofstream& log_file, LogLevel level,
                 std::string_view message) {
    log_file << current_time() << " - " << level << ": " << message
             << std::endl;
}

// Function to calculate the size of a directory and its contents
std::optional<uintmax_t> calculate_directory_size(const fs::path& dir_path,
                                                  std::ofstream& log_file) {
    uintmax_t size = 0;
    std::error_code ec;

    // Skip unreadable subdirectories instead of failing the whole walk
    fs::recursive_directory_iterator it(
        dir_path, fs::directory_options::skip_permission_denied, ec);
    const fs::recursive_directory_iterator end;

    while (!ec && it != end) {
        // Skip entries we can't stat or size, but keep counting the rest
        std::error_code entry_ec;
        if (it->is_regular_file(entry_ec)) {
            uintmax_t file_size = it->file_size(entry_ec);
            if (entry_ec) {
                log_message(log_file, LogLevel::ERROR,
                            "Unable to get size of: " + it->path().string() +
                                " (" + entry_ec.message() + ")");
            } else {
                size += file_size;
            }
        }
        it.increment(ec);
    }

    if (ec) {
        log_message(log_file, LogLevel::ERROR,
                    "Filesystem error: " + ec.message() +
                        " in directory: " + dir_path.string());
        return std::nullopt;
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

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " <directory_path> <log_file_path>"
                  << std::endl;
        return 1;
    }

    fs::path directory_path = argv[1];
    std::string log_file_path = argv[2];

    // Open the log file for writing
    std::ofstream log_file(log_file_path, std::ios::app);

    // Check if the log file was opened successfully
    if (!log_file.is_open()) {
        std::cerr << "Unable to open log file: " << log_file_path << std::endl;
        return 1;
    }

    // Get the current directory
    if (!fs::exists(directory_path) || !fs::is_directory(directory_path)) {
        std::cerr << "Invalid directory path: " << directory_path.string()
                  << std::endl;
        log_message(log_file, LogLevel::ERROR,
                    "Invalid directory path: " + directory_path.string());
        return 1;
    }

    try {
        // Iterate through the entries in the specified directory
        for (const auto& entry : fs::directory_iterator(directory_path)) {
            // Check if the entry is a directory and not hidden
            if (entry.is_directory() &&
                entry.path().filename().string()[0] != '.') {
                log_message(log_file, LogLevel::INFO,
                            "Processing directory: " + entry.path().string());
                if (auto dir_size =
                        calculate_directory_size(entry.path(), log_file)) {
                    std::cout << std::left << std::setw(30)
                              << entry.path().filename().string()
                              << " Size: " << std::setw(10)
                              << human_readable_size(*dir_size) << std::endl;
                } else {
                    std::cout << std::left << std::setw(30)
                              << entry.path().filename().string()
                              << " Size: " << std::setw(10) << "Error"
                              << std::endl;
                }
            }
        }
    } catch (const fs::filesystem_error& e) {
        log_message(log_file, LogLevel::ERROR,
                    "Filesystem error: " + std::string(e.what()));
    } catch (const std::exception& e) {
        log_message(log_file, LogLevel::ERROR,
                    "General exception: " + std::string(e.what()));
    }

    // The log file will be closed automatically when the ofstream object is
    // destroyed
    return 0;
}
