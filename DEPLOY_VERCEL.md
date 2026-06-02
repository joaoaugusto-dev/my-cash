# Deploy no Vercel

Este repo e um monorepo. Crie dois projetos na Vercel apontando para o mesmo
repositorio GitHub, mas com diretórios raiz diferentes.

## Projetos

- API: `src/api/my_cash`
- Interface: `src/interface`
- API production URL: `https://my-cash-api-nu.vercel.app/api`
- Interface production URL: `https://my-cash-interface.vercel.app`

No painel da Vercel, em cada projeto, use:

- Git repository: `joaoaugusto-dev/my-cash`
- Production branch: `main`
- Root Directory da API: `src/api/my_cash`
- Root Directory da interface: `src/interface`

Com isso, os dois projetos acompanham os commits do mesmo repositorio. Cada
um builda apenas o conteudo do seu diretorio.

## Variaveis de ambiente

API, em Production:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `CORS_ORIGIN`

Interface, em Production:

- `APP_ENV=production`
- `API_BASE_URL`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GOOGLE_WEB_CLIENT_ID`
- `OAUTH_REDIRECT_SCHEME`
- `OAUTH_REDIRECT_HOST`

Localmente, a interface usa `.env` em desenvolvimento. Para build de producao
local, use `.prod.env`:

```sh
cd src/interface
npm run build:prod
```

Na Vercel, o build da interface usa `.prod.env` se o arquivo existir. Em deploy
via GitHub, como `.prod.env` nao e commitado, o build usa as variaveis
cadastradas no projeto da Vercel e passa tudo como `--dart-define`.

## Comandos uteis

Criar e conectar via CLI:

```sh
vercel project add my-cash-api
vercel link --yes --project my-cash-api --cwd src/api/my_cash
vercel git connect https://github.com/joaoaugusto-dev/my-cash --cwd src/api/my_cash
vercel api /v10/projects/<API_PROJECT_ID> -X PATCH -F rootDirectory=src/api/my_cash --silent

vercel project add my-cash-interface
vercel link --yes --project my-cash-interface --cwd src/interface
vercel git connect https://github.com/joaoaugusto-dev/my-cash --cwd src/interface
vercel api /v10/projects/<INTERFACE_PROJECT_ID> -X PATCH -F rootDirectory=src/interface --silent
```

Depois confira no painel da Vercel se cada projeto ficou com o Root Directory
correto antes de confiar no deploy automatico.

Para deploy manual via CLI depois que o `rootDirectory` estiver configurado,
rode a partir da raiz do monorepo:

```sh
vercel deploy --prod --project my-cash-api --yes
vercel deploy --prod --project my-cash-interface --yes
```
