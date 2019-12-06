

#include <node.h>


#include <Engine.hpp>



void HelloWorld(const v8::FunctionCallbackInfo<v8::Value>& args)
{
  v8::Isolate* isolate = args.GetIsolate();
  auto message = v8::String::NewFromUtf8(isolate, "Hello from the native side!",v8::NewStringType::kNormal);

    
  args.GetReturnValue().Set(message.ToLocalChecked());
}


void Initialize(v8::Local<v8::Object> exports)
{
  NODE_SET_METHOD(exports, "helloWorld", HelloWorld);
}

NODE_MODULE(module_name, Initialize)