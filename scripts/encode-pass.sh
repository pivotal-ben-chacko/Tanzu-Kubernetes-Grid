#!/bin/bash

# Update password and then run this script to encode
password=changeme

echo -n $password | base64 
