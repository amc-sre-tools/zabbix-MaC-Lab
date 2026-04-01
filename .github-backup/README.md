# GitHub Actions Backup

> **Nota**: Este directorio contiene los workflows de GitHub Actions como respaldo.
> El CI/CD primario está implementado con **Jenkins** en POD1.

## Contenido

```
.github-backup/
├── actions/
│   ├── deploy-skill.yml
│   └── qa-skill.yml
└── workflows/
    ├── ci.yml
    └── cd.yml
```

## Activar GitHub Actions

Si deseas usar GitHub Actions en lugar de Jenkins:

```bash
# Mover de vuelta a .github/
mv .github-backup/workflows .github/
mv .github-backup/actions .github/
```

## Notas

- Los workflows usan **Podman** (no Docker)
- Requiere secrets en GitHub: `BAO_TOKEN`, `POSTGRES_PASSWORD`, etc.
- Compatible con GitHub Enterprise o GitHub.com

## Documentación

Ver README.md sección "CI/CD con Podman" para más detalles.