#include <stdio.h>
#include "erfa.h"
int main(void) {
  const int days[]={-36525,0,1,2,31,365,12345,36525};
  for(unsigned i=0;i<sizeof days/sizeof days[0];i++)
    for(int planet=1;planet<=8;planet++) {
      double pv[2][3];
      int status=eraPlan94(2451545.0+(double)days[i],0.0,planet,pv);
      if(status!=0)return 1;
      printf("%d %d",days[i],planet-1);
      for(int row=0;row<2;row++)for(int k=0;k<3;k++)printf(" %.17g",pv[row][k]);
      putchar('\n');
    }
  return 0;
}
