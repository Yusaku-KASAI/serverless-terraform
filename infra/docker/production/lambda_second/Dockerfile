FROM public.ecr.aws/lambda/python:3.13

# Install CloudWatch Lambda Insights Extension
RUN curl -O https://lambda-insights-extension.s3-ap-northeast-1.amazonaws.com/amazon_linux/lambda-insights-extension.rpm && \
    rpm -U lambda-insights-extension.rpm && \
    rm -f lambda-insights-extension.rpm

# Copy requirements.txt & Install the specified packages
COPY ./serverless /build
RUN pip install --upgrade pip

RUN if [ -f /build/requirements.txt]; then pip install -r /build/requirements.txt; fi

RUN rm -rf /build

# Copy function code
COPY ./serverless/lambda_second.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler (could also be done as a parameter override outside of the Dockerfile)
CMD [ "lambda_second.handler" ]
