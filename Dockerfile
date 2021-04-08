# I couldn't find a kubectl container that worked on armv7 so I built my own :/
FROM toxicglados/kubectl
COPY rollout.sh /bin/
CMD /bin/rollout.sh
