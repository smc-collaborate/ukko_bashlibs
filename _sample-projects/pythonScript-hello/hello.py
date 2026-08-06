#
#
from ukkoCommonCollection import app

#
################################################################################

APP_VERSION = "1.0.2"


def main():

    appChoices = app.Define(
        {
            "version": APP_VERSION,
            "description": f"I Say Hello",
            "options": [
                {"name": "person", "default": "Fred", "mayBeDirect": True},
                {"name": "helloCount", "min": 1, "max": 30, "default": 1},
            ],
        }
    ).parseParams()

    if appChoices["person"].lower() == "mary":
        app.error_exit_withSuggestion(
            "Mary doesn't like you.",
            f"Try {app.appInfo_cmdWithVariant_styled({'person':'Tom'})} instead",
        )

    for _ in range(appChoices["helloCount"]):
        print(f"Hello {appChoices['person'].title()}")


if __name__ == "__main__":
    app.doRun(main)
