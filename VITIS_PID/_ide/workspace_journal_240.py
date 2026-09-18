# 2026-09-16T21:08:43.898975300
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

platform = client.get_component(name="PID_Controller")
status = platform.build()

comp = client.get_component(name="PID_component")
comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

vitis.dispose()

