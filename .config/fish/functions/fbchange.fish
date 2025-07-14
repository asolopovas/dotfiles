function fbchange
    set models (fabric --listmodels)

    for model in $models
        echo $model
    end | fzf | read -l selected_model

    if not test -n "$selected_model"
        echo "Model selection cancelled."
        return
    end

    fabric --changeDefaultModel "$selected_model"
end
