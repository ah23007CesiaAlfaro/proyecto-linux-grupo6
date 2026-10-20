#!/bin/bash

echo "========================================"
echo "      REPORTE DE ESTADO DEL SISTEMA     "
echo "========================================"

echo "Fecha y hora actual: $(date)"

echo "Nombre del host: $(hostname)"

USUARIOS_CONECTADOS=$(who | wc -l)
echo "Número de usuarios conectados: $USUARIOS_CONECTADOS"

ESPACIO_LIBRE=$(df -h / | awk 'NR==2 {print $4}')
echo "Espacio libre en el disco principal: $ESPACIO_LIBRE"

RAM_DISPONIBLE=$(free -h | awk '/^Mem:/ {print $7}')
echo "Memoria RAM disponible: $RAM_DISPONIBLE"

CONTENEDORES_ACTIVOS=$(docker ps -q | wc -l)
echo "Número de contenedores Docker activos: $CONTENEDORES_ACTIVOS"

echo "========================================"
