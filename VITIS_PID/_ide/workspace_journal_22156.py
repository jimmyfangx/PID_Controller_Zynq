# 2026-09-16T11:39:01.625180
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

vitis.dispose()

