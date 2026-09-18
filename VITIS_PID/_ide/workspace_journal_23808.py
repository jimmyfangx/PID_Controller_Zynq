# 2026-09-17T11:21:24.751202700
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

vitis.dispose()

