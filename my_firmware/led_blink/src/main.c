#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

#define LED0_NODE DT_ALIAS(led0)

#if !DT_NODE_HAS_STATUS_OKAY(LED0_NODE)
#error "led0 devicetree alias is not available"
#endif

static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

int main(void)
{
	int ret;
	bool led_on = false;

	if (!gpio_is_ready_dt(&led)) {
		printk("LED GPIO device is not ready\n");
		return 0;
	}

	ret = gpio_pin_configure_dt(&led, GPIO_OUTPUT_INACTIVE);
	if (ret < 0) {
		printk("Failed to configure LED GPIO: %d\n", ret);
		return 0;
	}

	while (1) {
		ret = gpio_pin_toggle_dt(&led);
		if (ret < 0) {
			printk("Failed to toggle LED GPIO: %d\n", ret);
			return 0;
		}

		led_on = !led_on;
		printk("Onboard red LED: %s\n", led_on ? "on" : "off");
		k_msleep(500);
	}

	return 0;
}
