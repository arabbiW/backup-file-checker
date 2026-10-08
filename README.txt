Backup File Checker
-------------------

This project compares filenames in local backup directories against filenames stored in corresponding Amazon S3 backup locations for multiple servers.

Project structure
-----------------

backup-file-checker/
├── check_files.sh
├── servers.conf
├── logs/
└── README.txt

Requirements
------------

The machine running the script must have:

Bash
AWS CLI configured with permission to list the S3 locations
SSH key-based access to each configured server
Network access to the listed SSH hosts and S3 buckets

Run From the project directory:
-------------------------------

chmod +x check_files.sh
./check_files.sh