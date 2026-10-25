# Auto-Discovery Project

Infrastructure as Code that builds a self-healing AWS platform for the Pet Adoption (PetClinic) app and deploys it to staging and production automatically.

Application servers run in Auto Scaling Groups, so their IP addresses change as servers are added or replaced. An Ansible control node checks AWS every minute, finds every running server, and deploys the latest Docker image from Nexus to it. No one maintains a host list by hand.
