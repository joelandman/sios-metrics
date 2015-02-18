#!/usr/bin/perl
use strict;

while (1) {
   sleep 2;
   printf "\n#### sync:%i\n",time;
   printf "furlongs:%f\n",100 * rand;
   printf "fortnights:%f\n",100 * rand;
}
