FROM public.ecr.aws/lambda/python:3.12

WORKDIR ${LAMBDA_TASK_ROOT}

# Copy dependencies first for Docker layer caching
# (pip won't re-run if only code changes)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy Lambda function code
COPY src/lambda/ .

# Default handler - overridable via docker-compose
# Format: filename.functionname
CMD ["fetch_odds.handler"]