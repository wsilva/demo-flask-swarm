# Demo de aplicação flask usando Docker Compose e Docker Swarm

## O repositório
O repositório contem o código fonte da aplicação e o arquivo necessário para montar a imagem do container onde a aplicação irá rodar (Dockerfile) e como os serviços se comunicam (docker-compose.yml)

Esse exemplo está com meu nome de usuário no Docker Hub, para acompanhar você deve alterar no arquivo `docker-compose.yml` no serviço web em imagem de

```
    image: wfsilva/swarm-flask-app:v1
```

para:

``` 
    image: seu-nome-de-usuario-no-docker-hub/swarm-flask-app:v1
``` 

Note que tenho duas tags nesse repositório, v1 e v2 onde as diferenças são o arquivo `index.html` onde altero a frase `Curte Docker?` para `Curte Contêineres?` e o arquivo `docker-compose.yml` onde altero a imagem de `image: wfsilva/swarm-flask-app:v1` para image: `wfsilva/swarm-flask-app:v2`.
No seu caso deve colocar seu nome de usuário no Docker Hub para conseguir acompanhar os exemplos.

## A aplicação rodando localmente

Para testar a aplicação localmente devemos seguir os passos:

Construir as imagens:

```
    $ docker-compose build
```

Podemos ver se foi construída com o comando:

```
    $ docker images | grep flask
```

Para subir a aplicação:

```
    $ docker-compose up -d
```

Para abrir a aplicação no navegador (comando utilizado no OSX):

```
    $ open -a firefox http://$(docker-compose port web 80)
```

Testando a escalabilidade horizontal:

```
    $ docker-compose scale web=3
    $ docker-compose ps
```

Abrindo no navegador novamente (novamente comando utilizado no OSX):

```
    $ open -a firefox http://$(docker-compose port --index=2 web 80)
    $ open -a firefox http://$(docker-compose port --index=3 web 80)
```

Baixando os contêineres:

```
    $ docker-compose down
```

Enviando a imagem utilizada para o Docker Hub

```
    $ docker-compose push
```

O comando `docker deploy` ainda em 5/12/2016 está experimental mas já podemos gerar o arquivo `dab` com os serviços utilizados localmente para serem executados em um Docker Swarm com o comando `docker deploy demoswarmflaskapp.dab`

Para gerar o arquivo de bundle rodamos o comando

```
    $ docker-compose bundle --push-images
```

Para checar o arquivo gerado e ver seu conteúdo:

```
    $ ls -alh demoswarmflaskapp.dab
    $ cat demoswarmflaskapp.dab | less
```

## Montando um cluster de Docker 

Neste exemplo utilizei minha conta digitalocean, quem quiser pode utilizar sua própria conta, para isso é necessário utilizar o seu token no exemplo a seguir. Se não possuír conta na Digital Ocean e quiser testar, basta cadastrar pelo link https://m.do.co/c/8fcb11eb2657 você consegue US$ 10 (dez dólares) de crédito.

```
    $ DOTOKEN=$(cat ~/Dropbox/digital-ocean/DO_TOKEN.txt)
```

Desligue o Docker daemon em sua máquina (comando utilizado no OSX para desligar o Docker for Mac, confira em seu sistema como desligar o docker daemon):

```
    $ osascript -e 'quit app "Docker"'
```

Criando suas VMs rodando Docker na Digital Ocean. Neste exemplo estou utilizando o Docker machine para isso:

```
    $ for i in 1 2 3 4; do docker-machine create --driver digitalocean --digitalocean-access-token=$DOTOKEN host$i; done;
```

De maneira alternativa você pode fazer com VMs usando vmwarefusion ou virtualbox:

```
    $ for i in 1 2 3 4; do docker-machine create --driver vmwarefusion host$i; done;
    $ for i in 1 2 3 4; do docker-machine create --driver virtualbox host$i; done;
```

Pegando o endereço IP do primeiro host para usarmos como swarm manager:

```
    $ IPMANAGER=`docker-machine ip host1`
```

Utilizando o visualizador criado pelo Mano Marks do Docker:

```
    $ docker-machine ssh host1 \
        docker run -it -d \
        -p 8080:8080 \
        -e HOST=$IPMANAGER \
        -v /var/run/docker.sock:/var/run/docker.sock \
        manomarks/visualizer
    $ open -a Firefox "http://$IPMANAGER:8080"
```

Iniciando o Swarm usando swarmkit (docker 1.12):

```
    $ docker-machine ssh host1 docker swarm init
```

Pegando o Toke para adicionarmos mais máquinas ao cluster:

```
    $ SWMTOKEN=`docker-machine ssh host1 docker swarm join-token -q worker`
```

Juntando as demais máquinas ao cluster:

```
    $ for i in 2 3 4; do docker-machine ssh host$i docker swarm join --token $SWMTOKEN $IPMANAGER:2377; done
```

Apontando meu docker client para o daemon rodando no swarm:

```
    $ eval "$(docker-machine env host1)"
```

De maneira alternativa podemos acessar diretamente o host via ssh:

```
    $ docker-machine ssh host1
``` 

Mostrando os nós do swarm:

```
    $ docker node ls
```

Promovendo todos os nós de workers para managers:

```
    $ docker node promote host2
    $ docker node promote host3
    $ docker node promote host4
    $ docker node ls
```

Devido ao algoritmo RAFT sempre temos que trabalhar com números ímpares de manager para não termos problemas de eleição caso o manager principal cair, para isso tiramos a promoção do host4: 

```
    $ docker node demote host4
    $ docker node ls
```

Para subirmos nossa aplicação temos que criar uma rede do tipo overlay para que os serviços se comuniquem por ela:

```
    $ docker network create --driver overlay demo
```

Se estivermos utilizando o experimental que deve entrar no docker 1.13 podemos subir o arquivo `demoswarmflaskapp.dab` e rodar o comando:
    
```
    $ docker deploy demoswarmflaskapp.dab
```

Ou subirmos os serviços manualmente, atenção para colocar a imagem com seu nome de usuário do Docker Hub:

```
    $ docker service create --name cache --replicas 1 --network demo -p 6379:6379 redis
    $ docker service create --name flaskapp --replicas 1 --network demo -p 80:80 wfsilva/swarm-flask-app:v1
```

Para listar os serviços criados:

```
    $ docker service ls
```

Para ter mais detalhes de um serviço específico:

```
    $ docker service ps cache
    $ docker service ps flaskapp
    $ docker service inspect flaskapp --pretty
```

Visualizando a aplicação no navegador (novamente comandos do OSX):

```
    $ open -a Firefox "http://$IPMANAGER"
    $ open -a Firefox "http://$(docker-machine ip host2)"
    $ open -a Firefox "http://$(docker-machine ip host3)"
    $ open -a Firefox "http://$(docker-machine ip host4)"
```

Podemos perceber que o serviço é acessível em qualquer um dos 4 hosts mesmo com apenas 1 contêiner rodando devido a rede demo criada. 

Escalando o serviço web:

```
    $ docker service scale flaskapp=12
    $ docker service ps flaskapp
```

Se não quisermos monitorar pelo navegador podemos monitorar pela linha de comando usando o comando `watch` em um outro terminal (atenção, devemos apontar o docker client para o swarm nesse novo terminal):

```
    $ watch docker service ps flaskapp
```

## Fazendo updates

Em nosso exemplo alteramos o arquivo `index.html` e montamos uma nova imagem na tag v2, atenção que ao mudar a tag verifique se o nome da sua imagem mudou no `docker-compose.yml`.

```
    $ git checkout v2
    $ docker-compose build
    $ docker-compose push
```

Para alterar nosso serviço web de 2 em 2 contêineres e aguardando 5 segundos entre cada update:

```
    $ docker service update flaskapp --image wfsilva/swarm-flask-app:v2 --update-parallelism 2 --update-delay=5s
```

Podemos também alterar a quantidade de recursos por exemplo:

```
    $ docker service update flaskapp --limit-memory 256mb --update-parallelism 1 --update-delay=7s
```

Se precisarmos tirar um dos nós do swarm o comando abaixo vai fazer um reschedule de todos os containers que estavam rodando dentro dele:

```
    $ docker node update --availability drain host2
```

Colocando o nó de volta ao swarm:

```
    $ docker node update --availability active host2
```

Podemos apontar nossos docker clients em nossos dois terminais para outro manager:

```
    $ eval "$(docker-machine env host2)"
```

Podemos monitorar nossos nós com o comando:

```
    $ docker node ls
```

E em seguida desligar o primeiro manager e observar o cluster elegendo novo manager:

```
    $ docker-machine rm host1
```

