# fio-crystal-disk-mark

## fio.sh

```
Usage:
    fio.sh [-D|--dry-run] [--profile profile] --testfile <testfile>

    -h, --help
        show this help message
    -t, --testfile
        when testfile is a block device (eg. /dev/nvme0n1), fio will be executed in direct mode,
        otherwise, you need to set testfile as a regular file locate on the disk to be test.
    -p, --profile
        profile must be one of [all|seq|rand|readwrite|randrw]
    -s, --size
        testfile size when test in regular file mode
    -r, --runtime
        time_based runtime when test in direct mode
    -D, --dry-run
        dry_run mode, only print fio command to be execute with args

Examples:
    # fio in --direct mode
    fio.sh --testfile /dev/nvme0n1 --profile all

    # /mnt/nvme0n1 is mountpoint for /dev/nvme0n1
    fio.sh --testfile /mnt/nvme0n1/testdata --profile seq
```
