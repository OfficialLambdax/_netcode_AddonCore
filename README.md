# _netcode_AddonCore
Code libary for various Addons of _netcode

Requires _netcode_Core.au3 from
https://github.com/OfficialLambdax/_netcode_Core-UDF

_netcode_AddonCore_Experimental.au3 is nearly identical to _netcode_AddonCore.au3 and only comes with a different listing storage.
_netcode_AddonCore.au3 uses _storageOL and _netcode_AddonCore_Experimental uses _storageOLi.

_storageOLi is faster in every aspect, compared to _storageOL, but experimental.

The addons that the AddonCore currently provides with code, use socket lists. Socket lists are highly dynamic and these lists need to be constantly iterated. _storageOL which is based on a pure dictionary object provides the ability for highly dynamic lists, but its dictionary object to array conversion is fairly slow. The addons more often iterate through lists then they change the lists. Meaning that _storageOLi, which is a derivation of _storageGM, OL and AL that saves the AL lists until they are changed, is better for the Addons.

