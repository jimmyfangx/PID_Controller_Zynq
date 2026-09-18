# 2026-09-14T16:29:33.589462700
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

platform = client.get_component(name="PID_Controller")
status = platform.build()

comp = client.get_component(name="PID_app")
comp.build()

status = platform.build()

status = comp.clean()

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

status = platform.build()

comp.build()

status = comp.clean()

status = comp.clean()

status = comp.clean()

status = platform.build()

comp.build()

status = comp.clean()

status = platform.build()

client.delete_component(name="hello_world")

comp.build()

status = comp.clean()

status = platform.build()

comp.build()

client.delete_component(name="PID_app")

client.delete_component(name="componentName")

comp = client.create_app_component(name="PID_component",platform = "$COMPONENT_LOCATION/../PID_Controller/export/PID_Controller/PID_Controller.xpfm",domain = "standalone_ps7_cortexa9_0")

comp = client.get_component(name="PID_component")
status = comp.clean()

status = platform.build()

comp.build()

vitis.dispose()

