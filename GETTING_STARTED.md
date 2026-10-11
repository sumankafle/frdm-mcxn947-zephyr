# FRDM-MCXN947: Zephyr, VS Code, and onboard J-Link

This is the setup used on Ubuntu 26.04 for the FRDM-MCXN947. The board is supported by upstream Zephyr; the standalone target is `frdm_mcxn947/mcxn947/cpu0`.

## Install locations

| Component | Location / notes |
| --- | --- |
| Zephyr SDK 1.0.1 and ARM toolchain | `/opt/zephyr/sdk` |
| Zephyr Python 3.12 environment and `uv` | `/opt/zephyr/venv`, `/opt/zephyr/bin`, `/opt/zephyr/python` |
| Zephyr workspace | `~/work/FRDM-MCXN947/zephyrproject` |
| SEGGER J-Link 9.84 | `/opt/SEGGER/JLink_V984`; commands are on `PATH` |
| MCUXpresso for VS Code | VS Code extension |
| NXP MCUXpresso Installer and its managed environments | `~/MCUXpressoInstaller` and `~/.mcuxpressotools` |
| NXP LinkServer / MCU-Link tools | `/usr/local/LinkServer` |

The NXP installer manages its own tools in its standard locations; the Zephyr SDK and Zephyr Python environment are kept separately under `/opt/zephyr`. Do not install a second Zephyr SDK from the NXP installer.

## Install MCUXpresso and LinkServer

Install the **MCUXpresso for VS Code** extension from the VS Code Extensions view. In its MCUXpresso view, select **Quickstart > Open MCUXpresso Installer**. In the Installer, select and install **LinkServer**. This is needed for the NXP MCU-Link firmware utility; the VS Code extension alone does not install it.

On this machine, the Installer completed successfully with LinkServer 26.9.130 and NXP debugger support 26.09. It advised restarting VS Code so the updated environment is visible. The Zephyr workspace, SDK, and virtual environment are already installed as listed above.

## Workspace layout

Open the parent folder `~/work/FRDM-MCXN947` in VS Code. Keep Zephyr's source and modules separate from your applications:

```text
~/work/FRDM-MCXN947/
├── .vscode/
├── zephyrproject/
│   └── zephyr/
└── my_firmware/
    ├── helloworld/
    │   ├── CMakeLists.txt
    │   ├── prj.conf
    │   └── src/main.c
    ├── led_blink/
    │   ├── CMakeLists.txt
    │   ├── prj.conf
    │   └── src/main.c
    ├── project1/
    ├── project2/
    └── project3/
```

Each application is a standalone Zephyr app with its own `CMakeLists.txt`, `prj.conf`, and `src/main.c`. `helloworld` is based on Zephyr's Hello World sample but is independent of the upstream sample. Add later applications as sibling directories under `my_firmware/`; no shared VS Code setting needs to change.

`led_blink` is a small GPIO example that toggles the onboard red LED every 500 ms and prints its state to the serial console.

## Convert the onboard MCU-Link to J-Link

The FRDM-MCXN947 is currently enumerating as `NXP Semiconductors MCU-LINK FRDM-MCXN947 (r067) CMSIS-DAP V3.128` (USB ID `1fc9:0143`). The factory CMSIS-DAP firmware is not recognized by SEGGER J-Link. The following procedure replaces the onboard debug probe firmware with J-Link; it does not flash the MCXN947 application.

1. Restart VS Code after the NXP Installer completes.
2. Find the installed NXP firmware scripts. Follow symlinks with `-L`:

  ```sh
  find -L /usr/local/LinkServer -type f -iname 'program_JLINK*' -print -o -type f -iname 'program_CMSIS*' -print 2>/dev/null
  ```

  The installed J-Link script on this system is:

  ```text
  /usr/local/LinkServer/MCU-LINK_installer/scripts/program_JLINK
  ```

3. Disconnect the board's USB cable. Put a jumper across **J21** to place the onboard MCU-Link in ISP/DFU mode. Reconnect a data-capable USB cable to **J17**.
4. Run the script as your normal user:

  ```sh
  /usr/local/LinkServer/MCU-LINK_installer/scripts/program_JLINK
  ```

  When it says `Configure board for ISP mode and connect via USB then press Space`, confirm J21 is fitted and USB is on J17, then press Space. Wait for `Programmed successfully.` Do not run it with `sudo` unless the script explicitly requests it.
5. Disconnect USB, remove the J21 jumper, and reconnect USB to power-cycle the board.
6. Verify the USB ID has changed from the NXP CMSIS-DAP device to SEGGER J-Link (`1366:1024`):

  ```sh
  lsusb | grep -iE 'segger|j-link'
  ```

  Then verify J-Link can connect to the target:

  ```sh
  JLinkExe -device MCXN947_M33_0 -if SWD -speed auto
  ```

  It should connect rather than show `Cannot connect to the probe/programmer`. Type `exit` to close Commander. NXP's `program_CMSIS` script restores the factory CMSIS-DAP firmware.

## Build and flash your application

The helper script accepts any single application folder name under `my_firmware/` and keeps each build isolated under `zephyrproject/zephyr/build/apps/<app-name>`:

```sh
bash "$HOME/work/FRDM-MCXN947/scripts/zephyr-app.sh" build helloworld
bash "$HOME/work/FRDM-MCXN947/scripts/zephyr-app.sh" flash helloworld
```

For the LED example, use `led_blink` in place of `helloworld`. For a different app, replace the name with its folder name, for example `project1`. `ZEPHYR_BOARD`, `ZEPHYR_VENV`, and `ZEPHYR_SDK_INSTALL_DIR` can be overridden in the environment if using another board or install location. The default board target is `frdm_mcxn947/mcxn947/cpu0`.

The current `helloworld` app prints `Hello from Suman`. The build completed and the app was flashed successfully on this setup.

## Debug an application

### Step through source in VS Code

Install the recommended **Cortex-Debug** extension and reload VS Code. Build the selected application first using **Terminal > Run Build Task**. Open the **Run and Debug** view, select **Zephyr: Debug app (Cortex-Debug/J-Link)**, and press **F5**. Enter the application folder name when prompted. The debugger stops at `main`; use the toolbar's **Step Over (F10)**, **Step Into (F11)**, **Step Out (Shift+F11)**, and **Continue (F5)** controls. Source breakpoints can be set by clicking next to a line in `my_firmware/<app>/src/main.c`.

Open **Zephyr: Serial Console** in a second terminal to view UART output. Do not run the terminal GDB task at the same time as the VS Code debugger; both need the same J-Link probe.

### Terminal GDB alternative

Build the app first, then run **Terminal > Run Task > Zephyr: Debug app (J-Link)** and enter its folder name (for example, `helloworld`). This starts `west debug` with the app's ELF and opens an interactive GDB session in the terminal. The equivalent command is:

```sh
bash "$HOME/work/FRDM-MCXN947/scripts/zephyr-app.sh" debug helloworld
```

At the GDB prompt, enter one command per line: `break main`, `continue`, `next`, `step`, `print variable_name`, or `backtrace`. Use `continue` to resume and `quit` to end the debug session. The C/C++ extension uses the compile database generated for the most recently built app.

To see `Hello from Suman` while debugging, start **Zephyr: Serial Console** in a second terminal on `/dev/ttyACM0` at 115200 baud, then let the target continue past `main` or press RESET after detaching.

## View the serial console

Connect USB to **J17**. On this system, the virtual serial port is `/dev/ttyACM0`; the console is **115200 baud, 8 data bits, no parity, 1 stop bit**. The user is already in the `dialout` group and the device has user-accessible permissions.

Use the installed `screen` program:

```sh
screen /dev/ttyACM0 115200
```

Press the board's **RESET (SW1)** button. Expected output:

```text
Hello from Suman
```

Exit `screen` with **Ctrl-A**, then **K**, then **Y**. If there is no output, verify the port with `ls /dev/ttyACM*`, start `screen`, and press RESET again.

## Use the workspace in VS Code

Open the parent folder so the app, Zephyr checkout, and workspace tasks are all visible:

```sh
code "$HOME/work/FRDM-MCXN947"
```

The included `.vscode/tasks.json` provides generic **Zephyr: Build app**, **Zephyr: Flash app (J-Link)**, and **Zephyr: Build and flash app (J-Link)** tasks. Each asks for the folder name under `my_firmware/` (default `helloworld`). **Zephyr: Serial Console** asks for the serial device (default `/dev/ttyACM0`). The build helper updates `.vscode/compile_commands.json` to the most recently built app, so you do not need to edit workspace settings when adding projects.

## Quick command list

Run these from any terminal. The helper activates the Zephyr Python environment and sets the SDK paths automatically:

```sh
cd "$HOME/work/FRDM-MCXN947"
APP=helloworld

# Build only
bash scripts/zephyr-app.sh build "$APP"

# Flash an app that has already been built
bash scripts/zephyr-app.sh flash "$APP"

# Build and flash in one command
bash scripts/zephyr-app.sh build-flash "$APP"

# Start interactive J-Link/GDB debugging
bash scripts/zephyr-app.sh debug "$APP"

# In a separate terminal, view UART output
screen /dev/ttyACM0 115200
```

For another app, set `APP=project1` (or its folder name under `my_firmware/`) and reuse the same commands. No task or VS Code setting edits are needed. Press RESET (SW1) with the serial console open to see the app's startup message. In GDB, enter one command per line, for example `break main` then `continue`.