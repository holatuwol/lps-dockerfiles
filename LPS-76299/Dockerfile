FROM openjdk:8-jdk

# This file is not in version control
# Retrieve it with: python get_workspace.py

ADD LiferayWorkspace-installer.run /

ADD setup.sh /
RUN chmod u+x /setup.sh && /setup.sh

ADD deploy.sh /
RUN chmod u+x /deploy.sh

ENTRYPOINT ["sleep", "infinity"]