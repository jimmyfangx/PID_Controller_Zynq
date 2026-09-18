# 2026-09-15T16:05:11.284858200
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

vitis.dispose()

