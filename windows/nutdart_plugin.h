#ifndef FLUTTER_PLUGIN_NUTDART_PLUGIN_H_
#define FLUTTER_PLUGIN_NUTDART_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace nutdart {

class NutdartPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  NutdartPlugin();

  virtual ~NutdartPlugin();

  // Disallow copy and assign.
  NutdartPlugin(const NutdartPlugin&) = delete;
  NutdartPlugin& operator=(const NutdartPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace nutdart

#endif  // FLUTTER_PLUGIN_NUTDART_PLUGIN_H_