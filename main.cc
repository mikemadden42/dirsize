#include <filesystem>
#include <iomanip>
#include <iostream>
#include <string>

namespace fs = std::filesystem;

// Function to calculate the size of a directory and its contents
uintmax_t calculate_directory_size(const fs::path& dir_path) {
    uintmax_t size = 0;
    try {
        for (const auto& entry : fs::recursive_directory_iterator(dir_path)) {
            if (fs::is_regular_file(entry.status())) {
                size += fs::file_size(entry);
            }
        }
    } catch (const fs::filesystem_error& e) {
        std::cerr << "Filesystem error: " << e.what() << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "General exception: " << e.what() << std::endl;
    }
    return size;
}

// Function to convert size to human-readable format
std::string human_readable_size(uintmax_t size) {
    constexpr uintmax_t KB = 1024;
    constexpr uintmax_t MB = KB * 1024;
    constexpr uintmax_t GB = MB * 1024;

    if (size >= GB) {
        return std::to_string(size / GB) + " GB";
    } else if (size >= MB) {
        return std::to_string(size / MB) + " MB";
    } else if (size >= KB) {
        return std::to_string(size / KB) + " KB";
    } else {
        return std::to_string(size) + " bytes";
    }
}

int main() {
    // Get the current directory
    fs::path current_path = fs::current_path();

    try {
        // Iterate through the entries in the current directory
        for (const auto& entry : fs::directory_iterator(current_path)) {
            // Check if the entry is a directory and not hidden
            if (entry.is_directory() &&
                entry.path().filename().string()[0] != '.') {
                uintmax_t dir_size = calculate_directory_size(entry.path());
                std::cout << std::left << std::setw(30)
                          << entry.path().filename().string()
                          << " Size: " << std::setw(10)
                          << human_readable_size(dir_size) << std::endl;
            }
        }
    } catch (const fs::filesystem_error& e) {
        std::cerr << "Filesystem error: " << e.what() << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "General exception: " << e.what() << std::endl;
    }

    return 0;
}
