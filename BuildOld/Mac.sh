#!/bin/bash
set -ex
rm -rf ./Build/output/osx-arm64
# rm -rf ./Build/output/osx-x64
mkdir -p ./Build/output/osx-arm64
# mkdir -p ./Build/output/osx-x64

dotnet clean ./Drill/Drill.csproj
dotnet publish ./Drill/Drill.csproj -p:CreatePackage=false --framework net8.0-maccatalyst --runtime maccatalyst-arm64 --configuration Release  #-p:CodesignKey="${selectedSigningKey}" -p:CodesignProvision="${selectedProvisioningProfile}" -p:ArchiveOnBuild=true 
cp -R ./Drill/bin/Release/net8.0-maccatalyst/maccatalyst-arm64/Drill.app ./Build/output/osx-arm64
# cp -R ./Drill/bin/Release/net8.0-maccatalyst/maccatalyst-x64/Drill.app ./Build/output/osx-x64