%{
  configs: [
    %{
      name: "default",
      strict: false,
      checks: %{
        disabled: [
          {Credo.Check.Design.AliasUsage, false},
          {Credo.Check.Design.TagTODO, false},
          {Credo.Check.Refactor.Nesting, max_nesting: 3}
        ]
      }
    }
  ]
}
