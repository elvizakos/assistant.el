# assistant-mode #

assistant-mode is a minor mode for using LLM APIs inside the EMACS
editor, for chatting and help in coding.

## Installation ##

### Build tar package using make ###

```bash
# If not there already, go to assistant mode directory
cd /path/to/assistant-mode.el

# Clean possible previous builds.
make clean

# Make the package.
make
# This will generate a .tar.gz archive on the parent directory.
```

### Installing the package using make ###

```bash
# If not there already, go to assistant mode directory
cd /path/to/assistant-mode.el

# Remove any possible previous installation
make remove

# Install the package
make install
```

## Configure ##

### Add an API ###

To add and API, go to assistant customize page by typing <kbd>M-x customize-group &lt;RET&gt; assistant &lt;RET&gt;</kbd>.

Go to `Assistant Api Subscriptions:` and press the `INS` button.

On the field `Subscription name` give a name to the API.
On the `Api type` field, select from the list the type of the API. Possible values are:
 1. Ollama
 2. LM-Studio
 3. Open-WebUI
 4. Perplexica
 5. OpenAI V1
 6. Google Gemini

On the `Protocol` field, select the protocol type of the API. Possible values are http and https.
On the `Host name` field, type the host name or IP address.
On the `Port` field, type the port.
On the `API key` field, add the API key if there is any.

When finished, press the `apply and save` button on the top of the page and update the APIs by pressing <kbd>C-x / u</kbd> or the menu item on the asistant-mode lighter.
