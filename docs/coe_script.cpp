#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main (){
    freopen("inst_ram.coe","r",stdin);
    freopen("out.coe","w",stdout);
    char a[100];
    char b[100];
    scanf("%s",a);
    printf("%s ",a);
    scanf("%s",a);
    printf("%s ",a);
    scanf("%s",a);
    printf("%s\n",a);
    scanf("%s",a);
    printf("%s ",a);
    scanf("%s",a);
    printf("%s\n",a);
    int flag = 1;
    while(scanf("%s%s",a,b)!=EOF){
        printf("%s%s\n",b,a);
    }

    return 0;
}