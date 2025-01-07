return {
  {
    'f-person/git-blame.nvim',
    event = 'VeryLazy',
    opts = {
      enabled = true,
      message_template = ' <summary> • <date> • <author>',
      date_format = '%m-%d-%Y %H:%M:%S',
      max_commit_summary_length = 50,
    },
  },
}
