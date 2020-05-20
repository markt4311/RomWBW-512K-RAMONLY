@echo off
setlocal

PowerShell -ExecutionPolicy Unrestricted .\Build.ps1 %*
