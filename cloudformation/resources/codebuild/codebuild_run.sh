#!/usr/bin/env bash

./local_builds/codebuild_build.sh \
	-i aws/codebuild/standard:5.0 \
	-a ./output \
	-s ../../../ \
	-b ./buildspec-validate.yml \
	-e ./codebuild.env \
	-p admin \
	-c ~/.aws
