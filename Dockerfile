FROM python:3.9-slim as base

# The following is adapted from:
# https://sourcery.ai/blog/python-docker/

# Setup env
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1

FROM base AS python-deps

# Use the local apt-cache-ng proxy if it exists
RUN timeout --preserve-status 2 bash -c 'cat < /dev/null > /dev/tcp/10.0.0.1/3142' && { PROXY='Acquire::http { Proxy "http://10.0.0.1:3142"; };'; grep -qFxs -- "${PROXY}" "/etc/apt/apt.conf.d/01proxy" || { echo "${PROXY}" >> "/etc/apt/apt.conf.d/01proxy" || { echo "no network proxy on 10.0.0.1 - port 3142"; } } } || { echo "no network proxy on 10.0.0.1 - port 3142"; }

# Install pipenv and compilation dependencies
RUN pip install pipenv
RUN /usr/local/bin/python -m pip install --upgrade pip
RUN apt-get update && apt-get install -y --no-install-recommends gcc

RUN mkdir -p /base
WORKDIR /base

# Install python dependencies in /.venv
COPY Pipfile .
COPY Pipfile.lock .
COPY setup.cfg .
COPY setup.py .
COPY pyproject.toml .
RUN PIPENV_VENV_IN_PROJECT=1 pipenv install --deploy

FROM base AS runtime
VOLUME /home/appuser/log
# Copy virtualenv from python-deps stage
COPY --from=python-deps /base/.venv /base/.venv
ENV PATH="/base/.venv/bin:$PATH"

# Create and switch to a new user
RUN useradd --create-home appuser
WORKDIR /home/appuser

# Install application into container
COPY . .

RUN mkdir -p /home/appuser/log
RUN chown -R appuser:appuser /home/appuser

# Run the application
USER appuser
ENTRYPOINT ["python3", "-u", "main.py"]
