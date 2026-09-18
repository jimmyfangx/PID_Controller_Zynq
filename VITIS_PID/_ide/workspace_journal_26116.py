# 2026-09-16T13:18:09.382713
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

vitis.dispose()

