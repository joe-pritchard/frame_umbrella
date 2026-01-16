# FrameUmbrella

**To run locally:**

* `export SCENIC_LOCAL_TARGET=glfw # only needed on windows or CI`
* `export MIX_TARGET=host`
* `mix deps.get`
* `mix compile`
* `iex -S mix`

```
state = %FrameFirmware.FrameStateManager.State{wifi_configured?: false, ssid: "test_ssid"}
send(FrameUI.PubSub.FrameState, {:frame_state, state})
```

**To build:**

* `export MIX_TARGET=rpi0_2`
* `mix deps.get`
* `mix compile && cd ./apps/frame_firmware/ && mix firmware && mix upload <frame_ip_address> && cd ../..`

or

`mix compile && cd ./apps/frame_firmware/ && mix burn && cd ../..`

**SSH into it**

Nerves has been compiles with your SSH key authorised so you should be able to SSH straight into it using the same IP address as above. Obv you will need to have provisioned the wifi settings before you can do this.


