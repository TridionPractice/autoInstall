# autoInstall
Automatic installation scripts for Tridion Content Delivery

These scripts are an alternative to the quick install scripts that ship with SDL Web 8. Many of the techniques are similar, but the approach is different. Rather than aim for a quick demo, the idea is rather to have building blocks that allow you to compose a script for your own needs. 

The starting point is SetupContentDelivery.ps1. There you can see how each of the services in turn is installed, making use of various lower level helper scripts. 
