#ifndef M_ERROR_
#define M_ERROR_

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum error_kind { Anomaly, Discordance, Information } error_kind;

typedef struct m_error {
  char kind[2];
  char major_code[4];
  char minor_code[7];
  char description[81];
  char isisf[2];
  bool has_occurred;
} m_error;

int get_occurred_errors(m_error *errors, int size);

m_error *get_occurred_errors_items(int full_list_count, m_error *full_list,
                                   m_error *filtered_errors);

#endif /* M_ERROR_ */
