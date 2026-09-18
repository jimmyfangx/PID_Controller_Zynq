# 2026-09-18T10:47:51.827306
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

vitis.dispose()

