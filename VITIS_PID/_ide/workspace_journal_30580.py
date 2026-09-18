# 2026-09-14T15:50:24.527967600
import vitis

client = vitis.create_client()
client.set_workspace(path="VITIS_PID")

platform = client.create_platform_component(name = "PID_Controller",hw_design = "$COMPONENT_LOCATION/../../PID_controller_zybo/design_1_wrapper.xsa",os = "standalone",cpu = "ps7_cortexa9_0",domain_name = "standalone_ps7_cortexa9_0",compiler = "gcc")

comp = client.create_app_component(name="PID_app",platform = "$COMPONENT_LOCATION/../PID_Controller/export/PID_Controller/PID_Controller.xpfm",domain = "standalone_ps7_cortexa9_0")

platform = client.get_component(name="PID_Controller")
domain = platform.add_domain(cpu = "ps7_cortexa9_1",os = "freertos",name = "hello_world",display_name = "hello_world",support_app = "freertos_hello_world",generate_dtb = False,hw_boot_bin = "")

comp = client.create_app_component(name="hello_world",platform = "$COMPONENT_LOCATION/../PID_Controller/export/PID_Controller/PID_Controller.xpfm",domain = "standalone_ps7_cortexa9_0",template = "hello_world")

vitis.dispose()

