# 📑 Homelab Docker - Documentation Index

## 🚀 START HERE

**First time?** Read these files in order:
1. **[SUMMARY.md](SUMMARY.md)** ← Executive summary of what was delivered
2. **[DEPLOY.md](DEPLOY.md)** ← Quick 5-step deployment guide
3. **[.env.example](.env.example)** ← Create your `.env` with passwords

---

## 📂 File Organization

```
homelab-docker/
├── 📄 SUMMARY.md              ← Delivery summary & quick overview
├── 📄 DEPLOY.md               ← 5-step quick start (START HERE!)
├── 📄 README.md               ← Full comprehensive guide
├── 📄 MANIFEST.md             ← Complete file inventory & architecture
├── 📄 TROUBLESHOOTING.md      ← Debugging guide for issues
├── 📄 QUICKREF.sh             ← One-liner command reference
├── 📄 .env.example            ← Environment variables template
├── 🔧 setup.sh                ← Interactive setup script
│
├── 🐳 docker-compose.optiplex.yml   ← Main Optiplex stack
├── 🐳 docker-compose.pi3.yml        ← Raspberry Pi 3 stack
│
├── 📁 traefik/
│   ├── traefik.yml            ← Main Traefik configuration
│   └── dynamic_pi3.yml        ← Pi3 backend routing (UPDATE PI3_IP!)
│
├── 📁 headscale/
│   ├── config.yaml            ← Headscale VPN control plane config
│   └── acl.hujson             ← VPN access control policies
│
└── 📁 gatus/
    └── config.yaml            ← Uptime monitoring configuration
```

---

## 📖 Documentation Guide

### For Quick Deployment
| File | Purpose | Read Time |
|------|---------|-----------|
| **DEPLOY.md** | 5-step quick start | 5 min |
| **SUMMARY.md** | Executive summary | 10 min |
| **QUICKREF.sh** | Common commands | 5 min |

### For Comprehensive Understanding
| File | Purpose | Read Time |
|------|---------|-----------|
| **README.md** | Full guide with all details | 30 min |
| **MANIFEST.md** | Architecture & inventory | 20 min |
| **Compose files** | Service definitions | 20 min |

### For Troubleshooting
| File | Purpose | Read Time |
|------|---------|-----------|
| **TROUBLESHOOTING.md** | Debugging common issues | 15-30 min |
| **QUICKREF.sh** | Quick diagnostic commands | 5 min |

### For Configuration
| File | Purpose | Read Time |
|------|---------|-----------|
| **.env.example** | Environment template | 5 min |
| **traefik/traefik.yml** | TLS, entrypoints, providers | 10 min |
| **traefik/dynamic_pi3.yml** | Pi3 routing rules (UPDATE!) | 5 min |
| **headscale/config.yaml** | VPN settings | 5 min |
| **headscale/acl.hujson** | Network access rules | 5 min |

---

## 🎯 Use Cases & Which Files to Read

### "I just want to deploy this quickly"
1. Read **DEPLOY.md** (5 min)
2. Copy **.env.example** to **.env** and fill in values
3. Update **traefik/dynamic_pi3.yml** with Pi3 IP
4. Run the docker-compose commands from **DEPLOY.md**

### "I need to understand the architecture first"
1. Read **SUMMARY.md** (overview)
2. Read **MANIFEST.md** (detailed inventory)
3. View **README.md** section 2-4 (Traefik, Security, Networking)
4. Skim the docker-compose files

### "Something is broken, help!"
1. Check **TROUBLESHOOTING.md** for your symptom
2. Run diagnostic commands provided
3. Follow step-by-step solutions
4. If still stuck, check **QUICKREF.sh** for debugging commands

### "I want to add a new service"
1. Read **README.md** section "Advanced: Custom Service Routing"
2. Follow the 3-step template provided
3. Use existing service labels as examples
4. Restart with `docker-compose up -d`

### "I need to secure/harden this setup"
1. Read **README.md** section "Security: VPN-Only Services"
2. Review **headscale/acl.hujson** for network rules
3. Check firewall rules are correctly set
4. Verify VPN enforcement with test commands

### "How do I backup/restore?"
1. Read **README.md** section "Maintenance"
2. See **QUICKREF.sh** "Backup & Restore" section
3. Use provided docker commands for volume backup

---

## 🚦 Recommended Reading Order

### For New Deployment
```
1. SUMMARY.md (overview)
   ↓
2. .env.example (create your .env)
   ↓
3. DEPLOY.md (follow 5 steps)
   ↓
4. TROUBLESHOOTING.md (reference if issues)
   ↓
5. README.md (once running, read full docs)
```

### For Deep Dive
```
1. SUMMARY.md (what you have)
   ↓
2. MANIFEST.md (architecture)
   ↓
3. README.md (full guide)
   ↓
4. Individual config files (traefik, headscale, etc.)
   ↓
5. Docker-compose files (service definitions)
```

### For Troubleshooting
```
1. Check TROUBLESHOOTING.md for your symptom
   ↓
2. Run diagnostic commands provided
   ↓
3. Check logs with QUICKREF.sh commands
   ↓
4. Compare your config with examples in README.md
   ↓
5. Search for specific service in docker-compose file
```

---

## 📋 Quick Checklist Before Starting

- [ ] Read **DEPLOY.md** (5 min)
- [ ] Copy **.env.example** → **.env**
- [ ] Fill in **.env** with your passwords and IPs
- [ ] Update **traefik/dynamic_pi3.yml** with actual Pi3 IP
- [ ] Verify prerequisites: Docker, ports open, domain DNS
- [ ] Run Step 3 from **DEPLOY.md** (start Optiplex)
- [ ] Wait 2-3 minutes for TLS cert generation
- [ ] Run Step 4 from **DEPLOY.md** (start Pi3)
- [ ] Run smoke tests from **DEPLOY.md**
- [ ] Read **README.md** for full feature understanding

---

## 🔍 Find Information By Topic

### TLS / HTTPS / Let's Encrypt
- **DEPLOY.md** → "Step 3" (automatic cert generation)
- **README.md** → "Traefik Configuration" (TLS strategy)
- **TROUBLESHOOTING.md** → "TLS certificates not issuing"
- **QUICKREF.sh** → "TLS Certificate Check"

### VPN / Headscale / Tailscale
- **README.md** → "Headscale: Setup & Add Clients"
- **headscale/config.yaml** → Configuration details
- **headscale/acl.hujson** → Access control rules
- **TROUBLESHOOTING.md** → "Headscale clients can't register"

### Services Not Working
- **TROUBLESHOOTING.md** → "Connection refused" or "502 Bad Gateway"
- **QUICKREF.sh** → "Compose Management" & "Service-Specific Commands"
- **README.md** → "Troubleshooting" section

### Portainer (Container Management)
- **README.md** → "Portainer: Server & Agent Setup"
- **docker-compose.optiplex.yml** → `portainer` service definition
- **docker-compose.pi3.yml** → `portainer-agent` service definition

### Security / VPN-Only Access
- **README.md** → "Security: VPN-Only Services"
- **README.md** → "Traefik Configuration" → "VPN-Only Enforcement Options"
- **MANIFEST.md** → "Security Model"
- **TROUBLESHOOTING.md** → "403 Forbidden when accessing VPN-only service"

### Monitoring / Uptime
- **gatus/config.yaml** → Endpoint monitoring
- **README.md** → "Monitoring & Logs" section
- **QUICKREF.sh** → "Service Health" commands

### Backups / Restore
- **README.md** → "Maintenance" section
- **QUICKREF.sh** → "Backup & Restore" section

### Adding New Services
- **README.md** → "Advanced: Custom Service Routing"
- **docker-compose.optiplex.yml** → Service template examples
- **traefik/traefik.yml** → Provider configuration

### Resource Limits / Performance
- **MANIFEST.md** → "Performance & Resource Allocation"
- **TROUBLESHOOTING.md** → "High memory usage or container crashes"
- **docker-compose.optiplex.yml** → `deploy.resources` sections

---

## 🆘 Common Questions Answered

| Question | Answer | File |
|----------|--------|------|
| **Where do I start?** | Read DEPLOY.md | DEPLOY.md |
| **How do I set up environment variables?** | Copy .env.example → .env and fill in | .env.example |
| **What do I replace with my Pi3 IP?** | The PI3_IP placeholder in traefik/dynamic_pi3.yml | traefik/dynamic_pi3.yml |
| **How do TLS certificates work?** | HTTP challenge, automatic via Let's Encrypt | README.md → Traefik Configuration |
| **How do I prevent public internet access?** | IP whitelist middleware restricts to VPN IPs | README.md → Security |
| **How do I access services from outside?** | Use Tailscale VPN with Headscale | README.md → Headscale Setup |
| **What if TLS cert doesn't issue?** | Check TROUBLESHOOTING.md | TROUBLESHOOTING.md |
| **How do I add a new service?** | Follow template in README.md Advanced section | README.md |
| **How do I backup my data?** | Use docker volume backup commands | QUICKREF.sh or README.md |
| **What services run on which host?** | See MANIFEST.md Networking Summary | MANIFEST.md |

---

## 🔗 External References

### Documentation Sites
- **Traefik v3**: https://doc.traefik.io/traefik/
- **Headscale**: https://github.com/juanfont/headscale/wiki
- **Docker Compose**: https://docs.docker.com/compose/compose-file/compose-file-v3-8/
- **Let's Encrypt**: https://letsencrypt.org/docs/
- **Tailscale**: https://tailscale.com/kb/

### Tools
- **Traefik Dashboard** (after deployment): https://traefik.murphylab.app (VPN-only)
- **Portainer** (after deployment): https://portainer.murphylab.app (VPN-only)
- **Headscale API**: https://headscale.murphylab.app (VPN-only)

---

## 📞 Support Structure

### If You Need Help...

1. **Check the FAQ/Troubleshooting**
   - TROUBLESHOOTING.md for symptoms
   - QUICKREF.sh for diagnostic commands

2. **Search the Documentation**
   - Use Ctrl+F to search all `.md` files
   - Check MANIFEST.md index

3. **Review Examples**
   - Look at service definitions in docker-compose files
   - Compare with README.md examples

4. **Check Logs**
   - Commands in QUICKREF.sh
   - Service logs in TROUBLESHOOTING.md

5. **Verify Configuration**
   - Compare your .env with .env.example
   - Compare your configs with provided templates

---

## ✅ Completion Checklist

After reading this index:
- [ ] I understand the file structure
- [ ] I know where to find information by topic
- [ ] I know which files to read for quick start
- [ ] I know where to go for troubleshooting
- [ ] I'm ready to read DEPLOY.md and begin deployment

---

**Total Documentation**: ~2,500 lines across 8 files
**Setup Time**: 30 min (with this guide)
**Deployment Time**: 15 min (with DEPLOY.md)
**Verification Time**: 10 min (with smoke tests)

**Total Time to Full Deployment**: ~1 hour ⏱️

---

*Happy deploying!* 🚀
