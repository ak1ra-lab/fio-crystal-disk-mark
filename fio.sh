#!/bin/bash
# author: ak1ra
# date: 2024-10-17

set -o errexit -o nounset -o pipefail

this="$(readlink -f "${0}")"

declare size="5g"
declare runtime=300
declare dry_run="false"

declare -a fio_args fio_jobs

require_command() {
    for c in "$@"; do
        command -v "$c" >/dev/null || {
            echo >&2 "required command '$c' is not installed, aborting..."
            exit 1
        }
    done
}

usage() {
    prog="${this##*/}"
    cat <<EOF
Usage:
    ${prog} [-D|--dry-run] [--profile profile] --testfile <testfile>

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
    ${prog} --testfile /dev/nvme0n1 --profile all

    # /mnt/nvme0n1 is mountpoint for /dev/nvme0n1
    ${prog} --testfile /mnt/nvme0n1/testdata --profile seq

EOF
    exit 1
}

set_fio_jobs() {
    profile="$1"
    case "${profile}" in
    seq)
        fio_jobs=(
            seq-1m-q8t1.fio
            seq-128k-q32t1.fio
        )
        ;;
    rand)
        fio_jobs=(
            rand-4k-q1t1.fio
            rand-4k-q32tN.fio.j2
        )
        ;;
    readwrite)
        fio_jobs=(
            readwrite-1m-q8t1.fio
            readwrite-128k-q32t1.fio
        )
        ;;
    randrw)
        fio_jobs=(
            randrw-4k-q1t1.fio
            randrw-4k-q32tN.fio.j2
        )
        ;;
    all)
        fio_jobs=(
            seq-1m-q8t1.fio
            seq-128k-q32t1.fio
            rand-4k-q1t1.fio
            rand-4k-q32tN.fio.j2
            readwrite-1m-q8t1.fio
            readwrite-128k-q32t1.fio
            randrw-4k-q1t1.fio
            randrw-4k-q32tN.fio.j2
        )
        ;;
    *)
        usage
        ;;
    esac
}

loop_fio_jobs() {
    testfile="$1"
    jobs_dir="${this%/*}/jobs"
    output_dir="$(dirname "${this}")/output/${testfile##*/}"

    # Note that the Bash =~ operator only does regular expression matching when the right hand side is UNQUOTED
    # the string to the right of the operator is considered a POSIX extended regular expression
    if [[ -b "${testfile}" ]] || [[ "${testfile}" =~ ^/dev ]]; then
        fio_args=("--filename=${testfile}" "--direct=1" "--time_based" "--runtime=${runtime}")
    else
        fio_args=("--filename=${testfile}" "--size=${size}")
    fi

    # job without pathname
    for job in "${fio_jobs[@]}"; do
        if [ "${job##*.}" = "j2" ]; then
            job="${job%.j2}"
            sed -e 's%{{ nproc }}%'"$(nproc)"'%g' "${jobs_dir}/${job}.j2" >"${jobs_dir}/${job}"
        fi
        output="${output_dir}/${testfile##*/}-${job%.fio}-$(date +%F.%s).txt"
        if [ "${dry_run}" = "true" ]; then
            echo \
                fio "${jobs_dir}/${job}" --output="${output}" "${fio_args[@]}"
        else
            test -d "${output_dir}" || mkdir -p "${output_dir}"
            (
                set -x
                fio "${jobs_dir}/${job}" --output="${output}" "${fio_args[@]}"
            )
        fi
    done
}

main() {
    require_command jq fio

    # default options
    declare testfile=""
    declare profile="seq"

    getopt_args="$(
        getopt -o 'hDt:p:s:r:' \
            -l 'help,dry-run,testfile:,profile:,size:,runtime:' -- "$@"
    )"
    if ! eval set -- "${getopt_args}"; then
        usage
    fi

    while true; do
        case "$1" in
        -h | --help)
            usage
            ;;
        -D | --dry-run)
            dry_run=true
            shift
            ;;
        -t | --testfile)
            testfile="$2"
            shift 2
            ;;
        -p | --profile)
            profile="$2"
            shift 2
            ;;
        -s | --size)
            size="$2"
            shift 2
            ;;
        -r | --runtime)
            runtime="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "unexpected option: $1"
            usage
            ;;
        esac
    done

    test -n "${testfile}" || usage
    set_fio_jobs "${profile}"
    loop_fio_jobs "${testfile}"
}

main "$@"
