# 2026-09-17T17:36:24.926684500
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

platform = client.get_component(name="PID_Controller")
status = platform.build()

comp = client.get_component(name="PID_component")
comp.build()

vitis.dispose()

