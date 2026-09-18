# 2026-09-15T20:19:31.695733100
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

platform = client.get_component(name="PID_Controller")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../../PID_controller_zybo/design_1_wrapper.xsa")

vitis.dispose()

