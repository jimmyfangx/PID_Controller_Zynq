# 2026-09-14T18:55:08.693303700
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

platform = client.get_component(name="PID_Controller")
status = platform.build()

comp = client.get_component(name="PID_component")
comp.build()

comp = client.create_app_component(name="hello_world",platform = "$COMPONENT_LOCATION/../PID_Controller/export/PID_Controller/PID_Controller.xpfm",domain = "standalone_ps7_cortexa9_0",template = "hello_world")

status = platform.build()

comp.build()

status = platform.build()

status = platform.build()

comp = client.get_component(name="hello_world")
comp.build()

status = platform.build()

comp = client.get_component(name="PID_component")
comp.build()

status = platform.build()

comp.build()

comp = client.get_component(name="hello_world")
status = comp.clean()

status = platform.build()

comp.build()

status = platform.build()

comp = client.get_component(name="PID_component")
comp.build()

vitis.dispose()

