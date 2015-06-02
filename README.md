A collection of scripts related to coconut development and deployment.

In order to install an instance of:

* Coconut Factory (create new coconut applications: Separate forms & forms)
* Coconut Mobile (offline mobile html5 client)

You will need to run the deploy.rb script.

In order to succeed at this, you will need the following:

* ruby (to run the install script)
* git (to get the source code)
* node (to run gulp)
* gulp (to package the app for deployment)
* couchapp (the python version, installed with python-pip via "pip install couchapp")

You can then use the deploy.rb to install to a machine that has docker installed.

    ./deploy.rb [destination] [admin-username] [admin-password]

So to deploy this to localhost and setup couchdb with an admin user "admin" with password "password" you would do:

    ./deploy.rb localhost admin password


