#!/bin/bash

rm ascii.frag.qsb
rm ascii.vert.qsb

QSB="qsb-qt6"
$QSB --glsl "300 es,440" --hlsl 50 --msl 20 -o ascii.vert.qsb ascii.vert
$QSB --glsl "300 es,440" --hlsl 50 --msl 20 -o ascii.frag.qsb ascii.frag
