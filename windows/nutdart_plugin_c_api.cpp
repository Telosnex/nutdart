#include "include/nutdart/nutdart_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "nutdart_plugin.h"

void NutdartPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  nutdart::NutdartPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}