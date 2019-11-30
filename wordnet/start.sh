#!/bin/bash
docker pull jacopofar/wordnet-as-a-service
docker run -d --restart always -p 5679:5679 jacopofar/wordnet-as-a-service
