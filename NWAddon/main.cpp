

#include <node.h>

#include <Engine.hpp>

void HelloWorld(const v8::FunctionCallbackInfo<v8::Value> &args)
{
    v8::Isolate *isolate = args.GetIsolate();
    auto message = v8::String::NewFromUtf8(isolate, "Hello from the native side!", v8::NewStringType::kNormal);

    args.GetReturnValue().Set(message.ToLocalChecked());
}

Drill::Engine drillContext("owo");

void GetResults(const v8::FunctionCallbackInfo<v8::Value> &args)
{
    v8::Isolate* isolate = args.GetIsolate();
    //auto message = v8::String::NewFromUtf8(isolate, "Hello from the native side!",v8::NewStringType::kNormal);

    const auto results = drillContext.getResults();

    std::vector<std::string> converted;
    // for (const auto result : results)
    //     converted.push_back(result.path);

    v8::Handle<v8::Array> array = v8::Array::New(isolate, results.size());

     // Return an empty result if there was an error creating the array.
    if (array.IsEmpty())
    {
        args.GetReturnValue().Set(v8::Handle<v8::Array>());
        return;
    }
       

    for (int i = 0; i < results.size(); i++)
    {
        std::string s = results[i].path;
        
        
       // v8::Local<v8::Value> in = v8::Integer::New(isolate, (int)i);
        v8::Local<v8::String> st = v8::String::NewFromUtf8(isolate, results[i].path.c_str(), v8::NewStringType::kNormal).ToLocalChecked();
        array->Set(isolate->GetCurrentContext(), (uint32_t)i, st);
    }
    

    

    

    args.GetReturnValue().Set(array);
}




void StartDrilling(const v8::FunctionCallbackInfo<v8::Value> &args)
{
    drillContext.startDrilling();

}

void CreateContext(const v8::FunctionCallbackInfo<v8::Value> &args)
{
    

    drillContext = Drill::Engine("1080p");

    //v8::Isolate* isolate = args.GetIsolate();
    //auto message = v8::String::NewFromUtf8(isolate, "Hello from the native side!",v8::NewStringType::kNormal);

    //args.GetReturnValue().Set(message.ToLocalChecked());
}

void IsCrawling(const v8::FunctionCallbackInfo<v8::Value> &args)
{
    v8::Isolate *isolate = args.GetIsolate();
    const auto c = drillContext.isCrawling();
    auto message = v8::Boolean::New(isolate, c);
    args.GetReturnValue().Set(message);
}



void Initialize(v8::Local<v8::Object> exports)
{
    NODE_SET_METHOD(exports, "helloWorld", HelloWorld);
    NODE_SET_METHOD(exports, "createContext", CreateContext);
    NODE_SET_METHOD(exports, "getResults", GetResults);
    NODE_SET_METHOD(exports, "isCrawling", IsCrawling);
    NODE_SET_METHOD(exports, "startDrilling", StartDrilling);
}

NODE_MODULE(module_name, Initialize)