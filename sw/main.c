// docs/diseño/modulos/control_principal.md h.7
#include "control_principal.h"

int main(void)
{
  control_principal_arrancar();
  for(;;) control_principal_vuelta();
}
