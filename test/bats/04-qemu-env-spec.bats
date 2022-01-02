get_qemu_check_msg() {
    check-qemu-env.sh  2>&1 | grep -ow -c 'ERROR' || true
}

@test "Check welcome message" {
    run get_qemu_check_msg
     [ "$status" -eq 0 ]
}