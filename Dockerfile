FROM rockylinux:9

################################################################
# DEFINE versions
################################################################
ARG SAPCC_VERSION=2.19
ARG SAPJVM_VERSION=8.1.108
ARG SAPMACHINE_VERSION=25.0.2
ARG TARGETARCH

################################################################
# Upgrade + install dependencies
################################################################
#RUN dnf -y upgrade
#RUN dnf -y update; dnf clean all
RUN dnf -y install which unzip wget tar gzip net-tools less sysstat procps-ng; dnf clean all

################################################################
# Install dependencies and the SAP packages
################################################################

# HINT:
# In case automated download fails (see wget below) just download sapjvm + sapcc manually
# and put the downloaded files into a folder "sapdownloads" on the same level
# as this Dockerfile. Then pass them to the container by uncommenting the
# following command (then retry the next steps) + remove the 2 wget from RUN
# + adapt the zip filename and the 2 rpm filenames under RUN below:
#COPY sapdownloads /tmp/sapdownloads/

WORKDIR /tmp/sapdownloads

# download sapcc and java runtime + install based on architecture
# ATTENTION:
# This automated download automatically accepts SAP's End User License Agreement (EULA).
# Thus, when using this docker file as is you automatically accept SAP's EULA!

# amd64: SAPJVM (RPM) + SAP CC x64
# arm64: SAPMachine JDK (tar.gz) + SAP CC aarch64
# On arm64, SAPMachine is symlinked to /opt/sapjvm_8 so JAVA_HOME works for both architectures
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      echo "Building for arm64 - using SAPMachine JDK and SAP CC aarch64" && \
      wget -q -O sapmachine.tar.gz "https://github.com/SAP/SapMachine/releases/download/sapmachine-${SAPMACHINE_VERSION}/sapmachine-jdk-${SAPMACHINE_VERSION}_linux-aarch64_bin.tar.gz" && \
      mkdir -p /opt/sapmachine && \
      tar -xzf sapmachine.tar.gz -C /opt/sapmachine --strip-components=1 && \
      ln -s /opt/sapmachine /opt/sapjvm_8 && \
      wget --no-check-certificate --no-cookies --header "Cookie: eula_3_2_agreed=tools.hana.ondemand.com/developer-license-3_2.txt; path=/;" -S "https://tools.hana.ondemand.com/additional/sapcc-${SAPCC_VERSION}-linux-aarch64.zip" && \
      unzip sapcc-${SAPCC_VERSION}-linux-aarch64.zip && \
      rpm -i --nodeps com.sap.scc-ui-${SAPCC_VERSION}*.aarch64.rpm; \
    else \
      echo "Building for amd64 - using SAPJVM and SAP CC x64" && \
      wget --no-check-certificate --no-cookies --header "Cookie: eula_3_2_agreed=tools.hana.ondemand.com/developer-license-3_2.txt; path=/;" -S "https://tools.hana.ondemand.com/additional/sapjvm-${SAPJVM_VERSION}-linux-x64.rpm" && \
      rpm -i sapjvm-${SAPJVM_VERSION}-linux-x64.rpm && \
      wget --no-check-certificate --no-cookies --header "Cookie: eula_3_2_agreed=tools.hana.ondemand.com/developer-license-3_2.txt; path=/;" -S "https://tools.hana.ondemand.com/additional/sapcc-${SAPCC_VERSION}-linux-x64.zip" && \
      unzip sapcc-${SAPCC_VERSION}-linux-x64.zip && \
      rpm -i com.sap.scc-ui-${SAPCC_VERSION}*.x86_64.rpm; \
    fi && \
    rm -rf /tmp/sapdownloads/*

# set JAVA_HOME because this is needed by go.sh below
# On arm64, /opt/sapjvm_8 is a symlink to /opt/sapmachine
ENV JAVA_HOME=/opt/sapjvm_8/
#ENV CATALINA_BASE=/opt/sap/scc
#ENV CATALINA_HOME=/opt/sap/scc
#ENV CATALINA_TMPDIR=/opt/sap/scc/temp
#ENV SAPJVM_HOME=/opt/sapjvm_8/


# Recommended: Replace the Default SSL Certificate ==> https://help.sap.com/viewer/cca91383641e40ffbe03bdc78f00f681/Cloud/en-US/bcd5e113c9164ae8a443325692cd5b12.html
## Use a Self-Signed Certificate ==> https://help.sap.com/viewer/cca91383641e40ffbe03bdc78f00f681/Cloud/en-US/57cb635955224bd58ac917a42bead117.html
#RUN export JAVA_EXE=/opt/sapjvm_8/bin/java
#RUN cd /opt/sap/scc/config
# get the currenct password
#RUN /opt/sapjvm_8/bin/java -cp /opt/sap/scc/plugins/com.sap.scc.rt*.jar -Djava.library.path=/opt/sap/scc/auditor com.sap.scc.jni.SecStoreAccess -path /opt/sap/scc/scc_config -p
# => current passwd [csW47YRjogt98IZy]
# TODO: use the retrieved password via CLI instead of having it hard coded here:
#RUN /opt/sapjvm_8/bin/keytool -delete -alias tomcat -keystore ks.store -storepass csW47YRjogt98IZy
#RUN /opt/sapjvm_8/bin/keytool -keysize 4096 -genkey -v -keyalg RSA -validity 3650 -alias tomcat -keypass csW47YRjogt98IZy -keystore ks.store -storepass csW47YRjogt98IZy -dname "CN=SCC, OU=YourCompany, O=YourCompany"

# expose connector server
EXPOSE 8443
USER sccadmin
WORKDIR /opt/sap/scc

# survive container destruction/recreation
VOLUME /opt/sap/scc/config
VOLUME /opt/sap/scc/scc_config
VOLUME /opt/sap/scc/log

# finally run sapcc as PID 1
ENTRYPOINT [ "./go.sh" ]
