get_qemu_check_msg() {
    check-qemu-env.sh  2>&1 | grep -ow -c 'ERROR' || true
}


# test system viability for building muli-arch images
@test "Check QEMU report status" {
    run get_qemu_check_msg
     [ "$status" -eq 0 ]
}