# 🚀 Oracle ARM Deployer

> ⚠️ **Versão Beta** | 🖥️ **Somente Oracle Cloud Shell**

O **_Oracle ARM Deployer_** é um script de automação agressivo e resiliente projetado para vencer a escassez de recursos na **_Oracle Cloud (OCI)_**. Ele monitora e tenta incessantemente criar instâncias **_Always Free Ampere (A1)_** até obter sucesso, lidando automaticamente com o erro `Out of host capacity`.

### Por que tentativas contínuas?

Instâncias **_Ampere (A1)_** no Oracle Cloud Free Tier são **_extremamente escassas_**. A disponibilidade é imprevisível e você pode enfrentar `Out of host capacity` dezenas de vezes. Este script resolve esse problema:

- ⏰ Tenta indefinidamente com intervalo configurável (padrão: 30s)
- 🎯 Monitora em tempo real com contagem regressiva visual
- 📊 Registra todas as tentativas em logs para análise
- ✅ Para automaticamente ao conseguir a vaga

## 💎 Diferenciais

- 💻 **_Interface Visual Premium:_**  
  Utiliza bordas ASCII e cores para facilitar o monitoramento.

- 🔄 **_Persistência Implacável:_**  
  Loop infinito com contagem regressiva até a instância ser provisionada.

- 🔗 **_Integração com TMUX:_**  
  Cria sessões automáticas para que o script rode em segundo plano \__(background)_ sem interromper se você fechar o terminal.

- 📂 **_Gestão Inteligente de Logs:_**  
  Mantém apenas as últimas sessões de log para economizar espaço em disco.

- 🔍 **_Auto-Resolução de Infra:_**  
  Detecta automaticamente seu **_Compartment_**, **_Subnet_** e a última Imagem do **_Ubuntu 24.04 ARM_** disponível.

## 📸 Preview da Interface

Versão beta teste

<center>

![v1](/assets/0002.png)

</center>

## 🛠️ Pré-requisitos

1. **_OCI CLI Configurado:_**  
   Tenha o [OCI CLI instalado e autenticado](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm).

2. **_Dependências:_** `jq` e `tmux` já costumam vir pré-instalados no Oracle Cloud Shell.  
   Caso use ambiente local:

   ```bash
   sudo apt update && sudo apt install jq tmux -y
   ```

3. **_Chaves SSH (Obrigatório):_** Você precisa de um par de chaves para acessar sua instância futuramente.

### 🔑 Gerando Chaves SSH no Cloud Shell

Se você ainda não tem chaves, execute o comando abaixo no terminal da Oracle Cloud:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/oad_key
```

Pressione Enter em todas as perguntas _(não precisa de senha)_.

**_O que foi gerado?_**

- **_Chave Privada (oad_key):_**  
  É o seu "segredo".  
  **_Você DEVE_** baixar este arquivo para o seu PC local. Sem ele, você nunca conseguirá entrar no servidor.  
  Depois que copiar para o PC local, apague do servidor.

- **_Chave Pública (oad_key.pub):_**  
  É o que o script enviará para a Oracle para **_"fechar"_** a fechadura do seu servidor.

### 📤 Gerenciando Arquivos (Upload/Download)

O **_Oracle Cloud Shell_** possui uma interface facilitada para transferir arquivos sem usar comandos:

Na barra superior do terminal **_Cloud Shell_**, clique no ícone de engrenagem ⚙️ ou no menu de hambúrguer ☰ _(dependendo da versão)_.

1. **_Selecione Upload_** para enviar o script `oad-launcher.sh` pronto do seu PC para a nuvem.

2. **_Selecione Download_** para baixar suas **_chaves SSH_** _(`oad_key`)_ para o seu PC.

3. Ao baixar, forneça o caminho completo, _(ex: `/home/eu-usuario/.ssh/oad_key`)_.
   - **_Dica:_** Salve suas chaves em uma pasta segura no seu computador _(ex: `C:\Users\NomeDeUsuario\.ssh` no Windows ou `~/.ssh` no Linux/Mac)_.

## 🚀 Como usar

1. **_Crie ou envie o arquivo do script_**
   - Você pode usar o **_Upload_** _(explicado acima)_ ou criar manualmente:

   ```bash
   nano oad-launcher.sh
   ```

   - Cole o conteúdo do script e salve _(`CTRL+O`, `Enter`, `CTRL+X`)_.

2. **_Dê permissão de execução:_**

   ```bash
   chmod +x oad-launcher.sh
   ```

3. **_Execute o script:_**

   ```bash
   ./oad-launcher.sh
   ```

   > 💡 Você verá uma interface visual colorida com bordas ASCII (como mostrado em [Preview da Interface](#-preview-da-interface)) e uma contagem regressiva entre tentativas.

## 🕹️ Comandos Úteis do TMUX

O script inicia automaticamente dentro de uma sessão TMUX chamada `deploy`.

- **_Sair (sem parar o script):_** Pressione `CTRL+B` e depois `D`.

- **_Voltar para o script:_** Digite `tmux attach -t deploy`.

- **_Finalizar tudo:_** Pressione `CTRL+C` dentro da sessão.

## 📊 Logs e Monitoramento

Todas as tentativas de criação são registradas automaticamente:

- **_Local dos logs:_** `$HOME/oci_logs/session_*.log`
- **_Nomenclatura:_** `session_YYYYMMDD_HHMMSS.log` (timestamp de cada execução)
- **_Conteúdo:_** Exit code, saída completa, erros, e detalhes de cada tentativa

### Gerenciamento Automático

O script mantém apenas os **_últimas N sessões_** de log conforme a variável `MAX_LOG_FILES` (padrão: 3 arquivos). Logs mais antigos são deletados automaticamente.

### Analisando Logs

Para ver o progresso em tempo real:

```bash
tail -f $HOME/oci_logs/session_*.log
```

Para revisar uma tentativa específica, abra o arquivo de log correspondente:

```bash
cat $HOME/oci_logs/session_YYYYMMDD_HHMMSS.log
```

## ⚙️ Customização

No topo do arquivo `oad-launcher.sh`, você pode ajustar:

- **_OCPU_COUNT:_** Quantidade de cores (padrão 4).

- **_MEMORY_GB:_** Quantidade de RAM (padrão 24).

- **_SLEEP_TIME:_** Tempo de espera entre tentativas em segundos (padrão 30s).

- **_MAX_LOG_FILES:_** Quantidade de sessões de log históricos a manter (padrão 3, coloque 0 para desativar logs).

- **_SSH_PUBLIC_KEY_FILE_**: Caminho da sua **_chave pública SSH_** _(ex: `$HOME/.ssh/oad_key.pub`)_.

### Variáveis Auto-Resolvidas

As seguintes variáveis são **_opcionais_** no início do script. Se deixadas em branco (`""`), o script detecta automaticamente:

- **_COMPARTMENT_ID:_** Seu compartment Oracle Cloud (detecta o padrão automaticamente)
- **_AVAILABILITY_DOMAIN:_** Zona de disponibilidade (escolhe a primeira automaticamente)
- **_SUBNET_ID:_** Sub-rede para provisionar instância (escolhe a primeira automaticamente)

> 💡 **Dica:** Na maioria dos casos, deixe essas variáveis em branco. O script resolverá automaticamente ao executar.

## 🤔 Solução de Problemas Básico

### "OCI CLI not authenticated"

**_Causa:_** OCI CLI não está conectado ou configurado.

**_Solução:_** Execute no Cloud Shell:

```bash
oci setup config
```

Siga as instruções para autenticar com seu usuário Oracle Cloud.

### "Out of capacity" (mensagem repetida)

**_Esperado!_** Isso é normal para instâncias Ampere. O script continuará tentando indefinidamente.

**_Dica:_** Você pode deixar rodando por horas se necessário. Use TMUX para deixar em background (CTRL+B, depois D).

### "Image not found"

**_Causa:_** O script não conseguiu encontrar uma imagem Ubuntu 24.04 ARM compatível.

**_Solução:_** Verifique os logs:

```bash
cat $HOME/oci_logs/session_*.log | grep -i "image\|erro\|error"
```

Ensure que sua conta Oracle Cloud tem acesso a imagens Ubuntu 24.04 ARM.

## ✅ Próximos Passos

Após a instância ser criada com sucesso:

1. **_Encontre o IP e ID da instância:_**
   - O script exibe no terminal: `IP: xxx.xxx.xxx.xxx` e `ID: ocid1.instance.xxx`
   - Também está registrado no log: `$HOME/oci_logs/session_*.log`

2. **_Conecte via SSH:_**

   ```bash
   ssh -i ~/.ssh/oad_key ubuntu@xxx.xxx.xxx.xxx
   ```

   Substitua `xxx.xxx.xxx.xxx` pelo IP exibido anterior.

3. **_Você agora tem uma instância Always Free!_**
   - 4 OCPUs ARM Ampere A1
   - 24 GB de RAM
   - Acesso root via sudo
   - Tráfego de saída ilimitado no Free Tier

## 📑 Licença

Este projeto está sob a licença MIT. Veja o arquivo LICENSE para detalhes.

Desenvolvido para facilitar a vida de quem quer aproveitar o máximo do Oracle Cloud Free Tier. 🚀
